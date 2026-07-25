"""
main.py — Predictive resource allocation service (FastAPI).

SCHEMA: verified LIVE via Supabase MCP against project yhcyhwpdgqupylrnkqht on 2026-07-23
(not guessed) — public.staff.id (not staff_id), scheduling.time_slots.day is 3-letter
lowercase ('mon'..'fri', weekdays only, no weekend rows exist), scheduling.timetable and
scheduling.substitutions columns confirmed. See predictor.py's module docstring for the
full verified column list.

RECONCILED against services/timetable-solver/main.py on 2026-07-23 (Opus 4.8, local file
access):

  1. `/substitutes/recommend` request/response shape CONFIRMED to match the real endpoint.
     Request: {teacher_id: str, date: "YYYY-MM-DD", slot_id: int} — matches
     SubstituteRecommendRequest exactly. Response: {"candidates": [...]} where each
     candidate carries a `qualified` bool (plus teacher_id, teacher_name, weekly_load,
     max_periods, spare_capacity, reason, rank). `find_substitutes` reads .candidates and
     find_resource_gaps reads c["qualified"] — both correct. No shape fix was needed.
  2. `_safe_fetch` here is INTENTIONALLY a different helper from timetable-solver's. The
     solver's version is `(query_fn) -> (data, error)` (lambda-based, caller inspects the
     tuple); this one is a `(table, schema, **filters) -> list` convenience wrapper that
     raises HTTPException(500) on failure. They live in separate service files with no
     shared import, so there is no cross-service contract to drift — the only shared
     contract is the HTTP shape above, which is verified. The finance-schema divergence
     was about duplicated SCHEMA definitions, not per-service local helpers; not the same
     failure mode. Left as-is deliberately.

This is advisory-only by design (human-in-the-loop, per AGENTS.md hard rule) — it NEVER
writes to scheduling.substitutions itself. It only surfaces risk; an admin still uses the
existing /substitutes/recommend + /substitutes/commit flow to act.

Run: uvicorn main:app --port 8004  (8001 is timetable-solver, 8002 omr-pipeline, 8003
document-extraction — each service has its own assigned port per the project .env)
"""
import os
from datetime import date, datetime
from typing import Optional

import httpx
from dotenv import load_dotenv          # ADD THIS
load_dotenv()                            # ADD THIS

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client, Client

from predictor import compute_absence_risk_hybrid, find_resource_gaps

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
# TODO verify: does the running timetable-solver expose an internal recommend endpoint
# at this URL? Falls back to env var so it isn't hardcoded.
TIMETABLE_SOLVER_URL = os.environ.get("TIMETABLE_SOLVER_URL", "http://localhost:8001")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError(
        "SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set. Copy the pattern from "
        "services/timetable-solver/.env — do not hardcode these."
    )

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

app = FastAPI(title="predictive-engine")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO tighten before any real deploy — matches other services' dev-mode CORS for now
    allow_methods=["*"],
    allow_headers=["*"],
)


def _safe_fetch(table: str, schema: str, **filters):
    """
    Convenience fetch helper for this service. Intentionally distinct from
    timetable-solver's `_safe_fetch(query_fn) -> (data, error)` — see module docstring
    (reconciled 2026-07-23). This one builds a simple equality-filtered SELECT and raises
    HTTPException(500) on failure. No shared import with the solver, so no drift risk.
    """
    try:
        query = supabase.schema(schema).table(table).select("*")
        for key, val in filters.items():
            query = query.eq(key, val)
        resp = query.execute()
        return resp.data or []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB fetch failed ({schema}.{table}): {e}")


def find_substitutes(teacher_id: str, target_date: date, slot_id: int) -> list[dict]:
    """
    Calls the EXISTING, already-verified /substitutes/recommend endpoint on the
    timetable-solver service rather than reimplementing qualification/free-slot logic.
    Request/response shape CONFIRMED against services/timetable-solver/main.py on
    2026-07-23: sends {teacher_id, date (isoformat), slot_id}, reads {"candidates": [...]}
    with a `qualified` bool per candidate. See module docstring.
    """
    try:
        resp = httpx.post(
            f"{TIMETABLE_SOLVER_URL}/substitutes/recommend",
            json={"teacher_id": teacher_id, "date": target_date.isoformat(), "slot_id": slot_id},
            timeout=10.0,
        )
        if resp.status_code != 200:
            return []
        return resp.json().get("candidates", [])
    except Exception:
        # Predictive layer degrades gracefully — a solver-service hiccup should not crash
        # the forecast, it should just report "could not verify backup availability".
        return []


class AbsenceRiskRequest(BaseModel):
    target_date: date
    lookback_weeks: int = 12


class ResourceGapRequest(BaseModel):
    target_date: date
    lookback_weeks: int = 12
    risk_threshold: float = 0.15


@app.get("/health")
def health():
    return {"status": "ok", "service": "predictive-engine"}


@app.post("/predict/absence-risk")
def predict_absence_risk(req: AbsenceRiskRequest):
    """
    Returns a ranked absence-risk forecast for every teacher for the given date.
    Advisory only — does not write anything.
    """
    # public.staff PK is `id` (verified live) — not staff_id.
    staff_rows = _safe_fetch("staff", "public")
    teacher_ids = [s["id"] for s in staff_rows]
    if not teacher_ids:
        raise HTTPException(status_code=500, detail="No staff rows found — check public.staff")

    sub_rows = _safe_fetch("substitutions", "scheduling")
    # Normalize date strings from Supabase into date objects for the predictor.
    for row in sub_rows:
        if isinstance(row.get("date"), str):
            row["date"] = datetime.strptime(row["date"], "%Y-%m-%d").date()

    risk_scores = compute_absence_risk_hybrid(
        substitution_history=sub_rows,
        teacher_ids=teacher_ids,
        target_date=req.target_date,
        lookback_weeks=req.lookback_weeks,
    )
    return {"target_date": req.target_date.isoformat(), "risk_scores": risk_scores}


@app.post("/predict/resource-gaps")
def predict_resource_gaps(req: ResourceGapRequest):
    """
    The higher-value endpoint: cross-references absence risk against the actual timetable
    for that weekday, and checks real substitute availability for at-risk slots, so the
    admin sees "here's where you'll actually be short-staffed" rather than a flat list of
    risk percentages with no operational meaning.
    """
    staff_rows = _safe_fetch("staff", "public")
    teacher_ids = [s["id"] for s in staff_rows]

    sub_rows = _safe_fetch("substitutions", "scheduling")
    for row in sub_rows:
        if isinstance(row.get("date"), str):
            row["date"] = datetime.strptime(row["date"], "%Y-%m-%d").date()

    risk_scores = compute_absence_risk_hybrid(
        substitution_history=sub_rows,
        teacher_ids=teacher_ids,
        target_date=req.target_date,
        lookback_weeks=req.lookback_weeks,
    )

    # scheduling.time_slots.day is 3-letter lowercase ('mon'..'fri'), weekdays only —
    # verified live. Weekend target_date -> no slot rows exist, short-circuit cleanly.
    weekday_codes = ["mon", "tue", "wed", "thu", "fri", None, None]
    target_weekday = weekday_codes[req.target_date.weekday()]
    if target_weekday is None:
        return {
            "target_date": req.target_date.isoformat(),
            "gaps_found": 0,
            "critical_count": 0,
            "gaps": [],
            "note": "Weekend — no school day, no timetable slots exist for this date.",
        }

    # scheduling.time_slots PK is `id` (not `slot_id`) — timetable/substitutions reference
    # it as slot_id via FK, but on time_slots itself the column is `id`.
    slot_rows = _safe_fetch("time_slots", "scheduling", day=target_weekday)
    slot_ids_today = [s["id"] for s in slot_rows]

    timetable_rows = _safe_fetch("timetable", "scheduling")
    timetable_today = [r for r in timetable_rows if r.get("slot_id") in slot_ids_today]

    gaps = find_resource_gaps(
        risk_scores=risk_scores,
        timetable_rows=timetable_today,
        find_substitutes_fn=find_substitutes,
        target_date=req.target_date,
        risk_threshold=req.risk_threshold,
    )

    return {
        "target_date": req.target_date.isoformat(),
        "gaps_found": len(gaps),
        "critical_count": sum(1 for g in gaps if g["severity"] == "critical"),
        "gaps": gaps,
    }
