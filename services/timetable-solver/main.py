"""Timetable Solver — FastAPI microservice.

Wraps OR-Tools CP-SAT solver. Reads constraint data live from Supabase,
runs the solver, returns the timetable for human review. Does NOT write
to the DB on /generate (human-in-the-loop). Writes only via /commit.

Same pattern as omr-pipeline/main.py: service-role key, .schema() calls,
no PostgREST (so cross-schema FK gaps don't matter).

Start with:
    uvicorn main:app --reload --port 8001

Port 8001 is this service's assigned port (matches TIMETABLE_SOLVER_URL in the project
.env). Document-extraction owns 8003 — do NOT run this on 8003, it collides.
"""

import os
import sys
import json
import traceback
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from pydantic import BaseModel
from supabase import create_client, Client

# Locate .env two levels up from this file → project root
_env_path = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=_env_path)

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError(
        "SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY must be set in .env "
        f"(checked {_env_path})"
    )

_supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def _safe_fetch(query_fn):
    """Call a Supabase query and return (data, error). error is None on success."""
    try:
        return query_fn(), None
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        return None, str(exc)


app = FastAPI(
    title="Timetable Solver Service",
    description="OR-Tools CP-SAT solver wrapped as FastAPI — generates clash-free timetables.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)


# ── Pydantic models ────────────────────────────────────────────────

class CommitRequest(BaseModel):
    timetable: list[dict]


class SubstituteRecommendRequest(BaseModel):
    teacher_id: str
    date: str  # YYYY-MM-DD
    slot_id: int


class SubstituteCommitRequest(BaseModel):
    original_teacher_id: str
    substitute_teacher_id: str
    date: str  # YYYY-MM-DD
    slot_id: int
    class_id: str


# ── Health ─────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok"}


# ── Internal: load all constraints live from the DB ────────────────

def _load_constraints() -> dict:
    """Fetch classes, subjects, teachers, qualifications, rooms, time_slots."""

    # 1. Classes
    classes_resp, err = _safe_fetch(
        lambda: _supabase.schema("academic").table("classes")
            .select("*").execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"Classes fetch failed: {err}")
    classes = []
    class_ids = []
    for row in (classes_resp.data or []):
        class_ids.append(row["id"])
        classes.append({"id": row["id"], "name": row["name"], "subjects": []})
    ci_map = {c["id"]: i for i, c in enumerate(classes)}

    # 2. Subjects (academic.subjects has no FK index in PostgREST, so we match by name)
    subjects_resp, err = _safe_fetch(
        lambda: _supabase.schema("academic").table("subjects")
            .select("*").eq("class_id", class_ids[0] if class_ids else "00000000-0000-0000-0000-000000000000")
            .execute()
    )
    # Subject class_id FK doesn't resolve in PostgREST, so fetch ALL subjects
    # and match class_id manually (cross-schema FK issue — same as OMR pipeline).
    if err:
        raise HTTPException(status_code=500, detail=f"Subjects fetch failed: {err}")

    all_subjects = subjects_resp.data or []
    # Re-fetch without class_id filter since it might fail
    subj_resp2, err2 = _safe_fetch(
        lambda: _supabase.schema("academic").table("subjects")
            .select("*").execute()
    )
    if err2:
        all_subjects = subjects_resp.data or []  # fallback
    else:
        all_subjects = subj_resp2.data or []

    for s in all_subjects:
        idx = ci_map.get(s.get("class_id"))
        if idx is not None:
            classes[idx]["subjects"].append({
                "id": s["id"],
                "name": s["name"],
                "code": s.get("code"),
                "periods_per_week": s["periods_per_week"],
                "is_core": s.get("is_core", False),
            })

    # 3. Staff (public.staff — max_periods lives here, NOT in scheduling.*)
    # Load ALL staff, not just role in (teacher, principal): whether someone
    # teaches is decided by scheduling.teacher_subjects, NOT by their app role.
    # e.g. an 'admin' (accountant) can still be the assigned teacher for a
    # subject. Filtering by role here silently dropped a qualified teacher and
    # produced an incomplete timetable that falsely reported success.
    staff_resp, err = _safe_fetch(
        lambda: _supabase.table("staff")
            .select("*")
            .execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"Staff fetch failed: {err}")

    teachers = {}
    _teacher_names: dict[str, str] = {}
    teacher_ids = []
    for row in (staff_resp.data or []):
        max_p = row.get("max_periods")
        if max_p is None:
            max_p = 40  # generous default
        teachers[row["id"]] = {
            "name": row["full_name"],
            "max_periods": int(max_p),
        }
        _teacher_names[row["id"]] = row["full_name"]
        teacher_ids.append(row["id"])

    # 4. Teacher-subject qualifications (scheduling.teacher_subjects)
    # Again, PostgREST can't resolve academic.subjects → academic.subjects.name,
    # so we query teacher_subjects + subjects separately and join in Python
    # (same two-query pattern from OMR pipeline).
    quals_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("teacher_subjects")
            .select("*").execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"Qualifications fetch failed: {err}")

    teacher_subj_rows = quals_resp.data or []

    subject_lookup = {}
    for s in all_subjects:
        key = (s.get("class_id"), s["name"])
        subject_lookup.setdefault(key, [])

    # teacher_quals[tid] = [subject_name, ...] (per-class already filtered)
    teacher_quals: dict[str, list[str]] = {tid: [] for tid in teachers}
    for ts_row in teacher_subj_rows:
        tid = ts_row["teacher_id"]
        sid = ts_row["subject_id"]
        subj_row = next((s for s in all_subjects if s["id"] == sid), None)
        if subj_row:
            class_id = subj_row.get("class_id")
            subj_name = subj_row["name"]
            if tid in teacher_quals:
                teacher_quals[tid].append(subj_name)

    # 5. Rooms
    rooms_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("rooms")
            .select("*").execute()
    )
    rooms = rooms_resp.data or [] if not err else []
    rooms_raw = list(rooms)  # keep as-is for _solver

    # 6. Time slots
    slots_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("time_slots")
            .select("*").order("day").order("period_number").execute()
    )
    slot_rows = slots_resp.data or [] if not err else []
    day_set = list(dict.fromkeys(r["day"] for r in slot_rows))  # preserve order
    # (day, period_number) -> slot_id, so /generate output carries the real
    # slot_id that /commit needs (timetable.slot_id is NOT NULL). Can't derive
    # it from a day index — slot ids follow DB order (mon=1..6, tue=7..12), but
    # `days` is ordered differently.
    slot_id_map = {(r["day"], r["period_number"]): r["id"] for r in slot_rows}

    return {
        "days": day_set,
        "num_periods": 6,
        "classes": classes,
        "teachers": teachers,
        "teacher_quals": teacher_quals,
        "rooms": rooms,
        "_rooms_raw": rooms_raw,       # passed to solver verbatim
        "_teacher_names": _teacher_names,
        "_slot_id_map": slot_id_map,
    }


# ── Endpoints ──────────────────────────────────────────────────────

@app.post("/generate")
def generate_timetable():
    """Generate a clash-free timetable from live DB constraints.

    Returns JSON with:
      - status: "success" | "infeasible"
      - timetable: list of assignment dicts (only on success)
      - conflicts: list of conflict descriptions (only on infeasible)
      - summary: total assignments + per-class counts
    """
    try:
        constraints = _load_constraints()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))

    # Import solver lazily — heavy import, only happens on request
    sys.path.insert(0, str(Path(__file__).parent))
    from solver import solve_timetable

    result = solve_timetable(constraints)

    status_code = 200 if result["status"] == "success" else 422
    if result["status"] == "infeasible":
        raise HTTPException(status_code=status_code, detail=result)

    return result


@app.post("/commit")
def commit_timetable(req: CommitRequest):
    """Commit an (optionally admin-edited) timetable into scheduling.timetable.

    Each item in req.timetable must have: class_id, subject_id, teacher_id,
    slot_id. room_id is optional. Extra keys (day, period, *_name) are ignored.
    These are exactly the fields /generate emits, so its output can be posted
    back verbatim after human review.

    Uses the service-role key to bypass RLS. Writes with is_reviewed=true and
    a reviewed_at timestamp. reviewed_by is left null (this service has no auth
    context — the Flutter admin app can set it later if needed).

    NOTE: this is insert-only. It does NOT clear prior entries, so committing
    twice will duplicate rows — clear scheduling.timetable first if re-committing.
    """
    from datetime import datetime, timezone
    reviewed_at = datetime.now(timezone.utc).isoformat()

    required = ("class_id", "subject_id", "teacher_id", "slot_id")
    rows_to_insert = []
    for i, entry in enumerate(req.timetable):
        missing = [k for k in required if entry.get(k) is None]
        if missing:
            raise HTTPException(
                status_code=400,
                detail=f"timetable[{i}] missing required field(s): {', '.join(missing)}",
            )
        rows_to_insert.append({
            "class_id": entry["class_id"],
            "subject_id": entry["subject_id"],
            "teacher_id": entry["teacher_id"],
            "slot_id": entry["slot_id"],
            "room_id": entry.get("room_id"),
            "is_reviewed": True,
            "reviewed_at": reviewed_at,
        })

    if not rows_to_insert:
        raise HTTPException(status_code=400, detail="Empty timetable — nothing to commit.")

    try:
        resp = (
            _supabase
            .schema("scheduling")
            .table("timetable")
            .insert(rows_to_insert)
            .execute()
        )
        inserted = len(resp.data or [])
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        raise HTTPException(status_code=500, detail=f"DB insert failed: {exc}")

    return {"committed": inserted, "status": "ok"}


# ── Substitutes (filter/rank — NOT an OR-Tools re-solve) ───────────

def _parse_date(date_str: str):
    """Parse YYYY-MM-DD and return a date object; raises ValueError on bad input."""
    from datetime import date as date_cls
    return date_cls.fromisoformat(date_str)


def _weekday_to_slot_day(d) -> str:
    """Map Python weekday (Mon=0) to scheduling.time_slots.day values."""
    mapping = {0: "mon", 1: "tue", 2: "wed", 3: "thu", 4: "fri"}
    if d.weekday() not in mapping:
        raise HTTPException(
            status_code=400,
            detail=f"Date {d.isoformat()} is a weekend — school slots are Mon–Fri only.",
        )
    return mapping[d.weekday()]


@app.post("/substitutes/recommend")
def recommend_substitutes(req: SubstituteRecommendRequest):
    """Rank free substitute candidates for an absent teacher's slot.

    Read-only. Human-in-the-loop: does NOT write to scheduling.substitutions.
    Ranking:
      1. Free at date+slot (no timetable row, no non-cancelled sub covering them)
      2. Qualified for the subject's name (via teacher_subjects → subjects)
      3. Lighter weekly load, then spare capacity vs max_periods
    """
    try:
        target_date = _parse_date(req.date)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid date '{req.date}' — expected YYYY-MM-DD.",
        )

    expected_day = _weekday_to_slot_day(target_date)

    # 1. Slot must exist and match the date's weekday
    slot_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("time_slots")
            .select("*").eq("id", req.slot_id).execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"time_slots fetch failed: {err}")
    if not slot_resp.data:
        raise HTTPException(status_code=404, detail=f"slot_id {req.slot_id} not found.")
    slot = slot_resp.data[0]
    if slot["day"] != expected_day:
        raise HTTPException(
            status_code=400,
            detail=(
                f"slot_id {req.slot_id} is a '{slot['day']}' slot, but "
                f"{req.date} is a '{expected_day}'. Date and slot must match."
            ),
        )

    # 2. Absent teacher's assignment at this weekly slot
    assign_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("timetable")
            .select("*")
            .eq("teacher_id", req.teacher_id)
            .eq("slot_id", req.slot_id)
            .execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"timetable fetch failed: {err}")
    if not assign_resp.data:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Teacher {req.teacher_id} has no timetable assignment at "
                f"slot_id={req.slot_id}."
            ),
        )
    assignment = assign_resp.data[0]
    class_id = assignment["class_id"]
    subject_id = assignment["subject_id"]

    # Subject name (for qualification match + response)
    subj_resp, err = _safe_fetch(
        lambda: _supabase.schema("academic").table("subjects")
            .select("*").eq("id", subject_id).execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"subjects fetch failed: {err}")
    if not subj_resp.data:
        raise HTTPException(status_code=404, detail=f"subject_id {subject_id} not found.")
    subject = subj_resp.data[0]
    subject_name = subject["name"]

    # Class name (nice-to-have for reason strings)
    class_resp, err = _safe_fetch(
        lambda: _supabase.schema("academic").table("classes")
            .select("id,name").eq("id", class_id).execute()
    )
    class_name = (class_resp.data[0]["name"] if class_resp and class_resp.data else class_id)

    # Absent teacher name
    absent_resp, err = _safe_fetch(
        lambda: _supabase.table("staff")
            .select("id,full_name").eq("id", req.teacher_id).execute()
    )
    if err or not absent_resp.data:
        raise HTTPException(
            status_code=404,
            detail=f"teacher_id {req.teacher_id} not found in staff.",
        )
    absent_name = absent_resp.data[0]["full_name"]

    # 3. Load all staff + qualifications + timetable + existing subs
    staff_resp, err = _safe_fetch(
        lambda: _supabase.table("staff").select("*").execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"staff fetch failed: {err}")
    staff_rows = staff_resp.data or []

    quals_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("teacher_subjects")
            .select("*").execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"teacher_subjects fetch failed: {err}")

    all_subj_resp, err = _safe_fetch(
        lambda: _supabase.schema("academic").table("subjects")
            .select("id,name").execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"subjects list failed: {err}")
    subj_id_to_name = {s["id"]: s["name"] for s in (all_subj_resp.data or [])}

    # qualified subject names per teacher (match by subject name — same subject
    # name across classes counts as qualified, matching the solver's convention)
    teacher_qual_names: dict[str, set[str]] = {}
    for row in (quals_resp.data or []):
        tid = row["teacher_id"]
        name = subj_id_to_name.get(row["subject_id"])
        if name:
            teacher_qual_names.setdefault(tid, set()).add(name)

    tt_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("timetable")
            .select("teacher_id,slot_id").execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"timetable load failed: {err}")
    tt_rows = tt_resp.data or []

    # Teachers busy at this weekly slot from the base timetable
    busy_at_slot: set[str] = {
        r["teacher_id"] for r in tt_rows if r["slot_id"] == req.slot_id
    }

    # Weekly load per teacher (base timetable only)
    weekly_load: dict[str, int] = {}
    for r in tt_rows:
        weekly_load[r["teacher_id"]] = weekly_load.get(r["teacher_id"], 0) + 1

    # Existing substitutions on this date that occupy a substitute at this slot
    # (proposed + confirmed block the substitute; cancelled does not)
    sub_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("substitutions")
            .select("*")
            .eq("date", req.date)
            .eq("slot_id", req.slot_id)
            .execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"substitutions fetch failed: {err}")

    sub_busy: set[str] = set()
    already_covered = False
    for row in (sub_resp.data or []):
        if row.get("status") == "cancelled":
            continue
        if row.get("substitute_teacher_id"):
            sub_busy.add(row["substitute_teacher_id"])
        if (
            row.get("original_teacher_id") == req.teacher_id
            and row.get("status") in ("proposed", "confirmed")
            and row.get("substitute_teacher_id")
        ):
            already_covered = True

    candidates = []
    for staff in staff_rows:
        tid = staff["id"]
        if tid == req.teacher_id:
            continue  # can't substitute for yourself

        # Free? No base assignment at this slot AND not already covering a sub
        if tid in busy_at_slot or tid in sub_busy:
            continue

        max_p = staff.get("max_periods")
        if max_p is None:
            max_p = 40
        max_p = int(max_p)
        load = weekly_load.get(tid, 0)
        spare = max(0, max_p - load)
        qualified = subject_name in teacher_qual_names.get(tid, set())
        name = staff.get("full_name") or tid

        if qualified:
            reason = (
                f"Qualified for {subject_name}; free on {slot['day']} P{slot['period_number']}; "
                f"weekly load {load}/{max_p} ({spare} spare)."
            )
        else:
            reason = (
                f"Free on {slot['day']} P{slot['period_number']} but not listed as "
                f"qualified for {subject_name}; weekly load {load}/{max_p} ({spare} spare)."
            )

        candidates.append({
            "teacher_id": tid,
            "teacher_name": name,
            "qualified": qualified,
            "weekly_load": load,
            "max_periods": max_p,
            "spare_capacity": spare,
            "reason": reason,
        })

    # Rank: qualified first, then lighter load, then more spare, then name
    candidates.sort(
        key=lambda c: (
            0 if c["qualified"] else 1,
            c["weekly_load"],
            -c["spare_capacity"],
            c["teacher_name"],
        )
    )
    for i, c in enumerate(candidates, start=1):
        c["rank"] = i

    return {
        "status": "ok",
        "absent_teacher_id": req.teacher_id,
        "absent_teacher_name": absent_name,
        "date": req.date,
        "slot_id": req.slot_id,
        "slot": {
            "day": slot["day"],
            "period_number": slot["period_number"],
            "start_time": slot.get("start_time"),
            "end_time": slot.get("end_time"),
        },
        "class_id": class_id,
        "class_name": class_name,
        "subject_id": subject_id,
        "subject_name": subject_name,
        "already_covered": already_covered,
        "candidates": candidates,
        "candidate_count": len(candidates),
    }


@app.post("/substitutes/commit")
def commit_substitute(req: SubstituteCommitRequest):
    """Persist the admin's chosen substitute as a confirmed row.

    Human-in-the-loop: only what is explicitly submitted is written. Does NOT
    auto-pick the top recommendation. Uses service-role key (bypasses RLS).
    status is set to 'confirmed' because an admin has already chosen.
    """
    try:
        target_date = _parse_date(req.date)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid date '{req.date}' — expected YYYY-MM-DD.",
        )

    if req.original_teacher_id == req.substitute_teacher_id:
        raise HTTPException(
            status_code=400,
            detail="substitute_teacher_id cannot equal original_teacher_id.",
        )

    expected_day = _weekday_to_slot_day(target_date)

    # Validate slot
    slot_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("time_slots")
            .select("*").eq("id", req.slot_id).execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"time_slots fetch failed: {err}")
    if not slot_resp.data:
        raise HTTPException(status_code=404, detail=f"slot_id {req.slot_id} not found.")
    slot = slot_resp.data[0]
    if slot["day"] != expected_day:
        raise HTTPException(
            status_code=400,
            detail=(
                f"slot_id {req.slot_id} is a '{slot['day']}' slot, but "
                f"{req.date} is a '{expected_day}'."
            ),
        )

    # Original teacher must actually teach this class at this slot
    assign_resp, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("timetable")
            .select("*")
            .eq("teacher_id", req.original_teacher_id)
            .eq("slot_id", req.slot_id)
            .eq("class_id", req.class_id)
            .execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"timetable fetch failed: {err}")
    if not assign_resp.data:
        raise HTTPException(
            status_code=400,
            detail=(
                f"No timetable row for original_teacher={req.original_teacher_id} "
                f"class={req.class_id} slot={req.slot_id}."
            ),
        )

    # Both staff ids must exist
    for label, tid in (
        ("original_teacher_id", req.original_teacher_id),
        ("substitute_teacher_id", req.substitute_teacher_id),
    ):
        staff_check, err = _safe_fetch(
            lambda tid=tid: _supabase.table("staff")
                .select("id").eq("id", tid).execute()
        )
        if err:
            raise HTTPException(status_code=500, detail=f"staff fetch failed: {err}")
        if not staff_check.data:
            raise HTTPException(status_code=404, detail=f"{label} {tid} not found in staff.")

    # Soft clash guard: refuse if substitute is already busy at this weekly slot
    # or already covering a non-cancelled sub at this date+slot.
    busy_tt, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("timetable")
            .select("id")
            .eq("teacher_id", req.substitute_teacher_id)
            .eq("slot_id", req.slot_id)
            .execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"timetable clash check failed: {err}")
    if busy_tt.data:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Substitute {req.substitute_teacher_id} already has a timetable "
                f"assignment at slot_id={req.slot_id}."
            ),
        )

    busy_sub, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("substitutions")
            .select("id,status")
            .eq("date", req.date)
            .eq("slot_id", req.slot_id)
            .eq("substitute_teacher_id", req.substitute_teacher_id)
            .execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"substitutions clash check failed: {err}")
    active = [r for r in (busy_sub.data or []) if r.get("status") != "cancelled"]
    if active:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Substitute {req.substitute_teacher_id} is already covering a "
                f"substitution on {req.date} slot_id={req.slot_id}."
            ),
        )

    # Also refuse duplicate covering for the same original absence
    existing, err = _safe_fetch(
        lambda: _supabase.schema("scheduling").table("substitutions")
            .select("id,status,substitute_teacher_id")
            .eq("date", req.date)
            .eq("slot_id", req.slot_id)
            .eq("original_teacher_id", req.original_teacher_id)
            .eq("class_id", req.class_id)
            .execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"duplicate check failed: {err}")
    active_existing = [r for r in (existing.data or []) if r.get("status") != "cancelled"]
    if active_existing:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Absence already covered (substitution id="
                f"{active_existing[0]['id']}, status={active_existing[0]['status']}). "
                f"Cancel it first if you need to reassign."
            ),
        )

    row = {
        "original_teacher_id": req.original_teacher_id,
        "substitute_teacher_id": req.substitute_teacher_id,
        "date": req.date,
        "slot_id": req.slot_id,
        "class_id": req.class_id,
        "status": "confirmed",  # admin already chose — not auto-proposed
    }

    try:
        resp = (
            _supabase
            .schema("scheduling")
            .table("substitutions")
            .insert(row)
            .execute()
        )
        inserted = (resp.data or [None])[0]
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        raise HTTPException(status_code=500, detail=f"DB insert failed: {exc}")

    if not inserted:
        raise HTTPException(status_code=500, detail="Insert returned no row.")

    return {
        "status": "ok",
        "committed": 1,
        "substitution": inserted,
    }
