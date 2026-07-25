"""
main.py -- OMR Pipeline FastAPI microservice
Wraps scan_omr.scan() and writes results to Supabase attendance.records.

Start with:
    uvicorn main:app --reload --port 8002

POST /scan
  Form fields:
    - image:    UploadFile  (jpg/png photo of filled-in OMR sheet)
    - template: UploadFile  (the class_8A_template.json for this sheet)
    - class_id: str         (UUID of the class in academic.classes)
    - date:     str (optional, ISO YYYY-MM-DD; defaults to today if omitted)

Returns JSON:
  {
    "summary": {"total": 40, "present": 36, "absent": 2, "needs_review": 2},
    "records":  [
      {"roll_no": 1, "student_id": "uuid", "student_name": "Aarav Sharma",
       "status": "present", "confidence": 0.69, "needs_review": false, "review_reason": null},
      ...
    ],
    "inserted": 40,
    "replaced": 0   # prior OMR rows for this date+class deleted before insert (dedup)
  }
"""

import os
import sys
import tempfile
import datetime
import traceback
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from supabase import create_client, Client

# ---- locate and load .env two levels up (project root) ----
env_path = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(dotenv_path=env_path)

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print(
        "ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in .env "
        f"(looked at: {env_path})",
        file=sys.stderr,
    )
    _supabase = None
else:
    _supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


# ---- import scan_omr from same directory ----
sys.path.insert(0, str(Path(__file__).parent))
import scan_omr  # noqa: E402


app = FastAPI(
    title="OMR Attendance Pipeline",
    description="Scans a photographed OMR attendance sheet and writes results to Supabase.",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok", "supabase_configured": _supabase is not None}


@app.post("/scan")
async def scan_sheet(
    image: UploadFile = File(..., description="Photo of the filled OMR sheet (jpg/png)"),
    template: UploadFile = File(..., description="The template.json for this sheet"),
    class_id: str = Form(..., description="UUID of the class (academic.classes.id)"),
    date: str = Form(
        default="",
        description="Attendance date YYYY-MM-DD (defaults to today if omitted)",
    ),
):
    if _supabase is None:
        raise HTTPException(
            status_code=503,
            detail="Supabase not configured -- check SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env",
        )

    # --- Resolve date ---
    attendance_date = date.strip() if date.strip() else datetime.date.today().isoformat()
    try:
        datetime.date.fromisoformat(attendance_date)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid date format: {attendance_date!r}. Use YYYY-MM-DD.")

    # --- Write uploads to temp files ---
    with tempfile.TemporaryDirectory() as tmpdir:
        img_suffix = Path(image.filename).suffix if image.filename else ".jpg"
        img_path = os.path.join(tmpdir, f"sheet{img_suffix}")
        tmpl_path = os.path.join(tmpdir, "template.json")
        out_path = os.path.join(tmpdir, "result.json")

        img_bytes = await image.read()
        with open(img_path, "wb") as f:
            f.write(img_bytes)

        tmpl_bytes = await template.read()
        with open(tmpl_path, "wb") as f:
            f.write(tmpl_bytes)

        # --- Run the OMR scanner (no changes to its internals) ---
        try:
            scan_result = scan_omr.scan(img_path, tmpl_path, out_path)
        except RuntimeError as exc:
            raise HTTPException(status_code=422, detail=str(exc))
        except Exception as exc:
            traceback.print_exc()
            raise HTTPException(status_code=500, detail=f"Scanner error: {exc}")

    raw_results = scan_result.get("results", [])

    # --- Load class roster from Supabase: {roll_no -> {student_id, full_name}} ---
    # NOTE: PostgREST can't auto-resolve cross-schema FK (academic.class_roster -> public.students),
    # so we do two separate queries and join in Python.
    try:
        roster_resp = (
            _supabase
            .schema("academic")
            .table("class_roster")
            .select("roll_no, student_id")
            .eq("class_id", class_id)
            .execute()
        )
    except Exception as exc:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Roster lookup failed: {exc}")

    roster_rows = roster_resp.data or []
    student_ids = [row["student_id"] for row in roster_rows if row.get("student_id")]

    # Fetch student names from public schema
    student_names: dict[str, str] = {}
    if student_ids:
        try:
            names_resp = (
                _supabase
                .schema("public")
                .table("students")
                .select("id, full_name")
                .in_("id", student_ids)
                .execute()
            )
            for s in (names_resp.data or []):
                student_names[s["id"]] = s["full_name"]
        except Exception as exc:
            traceback.print_exc()
            # Non-fatal: names are nice-to-have; proceed without them
            print(f"Warning: could not fetch student names: {exc}", file=sys.stderr)

    roster = {}
    for row in roster_rows:
        rn = row["roll_no"]
        sid = row["student_id"]
        roster[rn] = {
            "student_id": sid,
            "full_name": student_names.get(sid),
        }

    # --- Build records to insert ---
    records_to_insert = []
    per_student_breakdown = []

    for item in raw_results:
        roll_no = item["roll_no"]
        matched = roster.get(roll_no)

        if matched:
            student_id = matched["student_id"]
            student_name = matched["full_name"]
            needs_review = item["needs_review"]
            review_reason = None
            if needs_review and item["status"] is None:
                review_reason = "Ambiguous bubble fill -- both or neither bubble marked"
            elif needs_review:
                review_reason = "Bubble fill confidence is low -- verify manually"
        else:
            student_id = None
            student_name = None
            needs_review = True
            review_reason = f"No roster match for roll_no {roll_no} in class {class_id}"

        record = {
            "student_id": student_id,
            "class_id": class_id,
            "date": attendance_date,
            "status": item["status"],
            "method": "omr",
            "confidence": item["confidence"],
            "needs_review": needs_review,
            "review_reason": review_reason,
            "marked_by": None,
        }
        records_to_insert.append(record)

        per_student_breakdown.append({
            "roll_no": roll_no,
            "student_id": student_id,
            "student_name": student_name,
            "status": item["status"],
            "confidence": item["confidence"],
            "needs_review": needs_review,
            "review_reason": review_reason,
        })

    # --- Dedup: a re-scan replaces, never appends ---
    # DELIBERATE CHOICE (option A: delete-then-insert over option B: reject-and-error).
    # Real admin workflow is "re-scan because the first photo was blurry/tilted" — rejecting
    # with "records already exist, delete them first" would force the admin to drop to a DB
    # tool just to recover from a bad photo, which is hostile. Treating a re-scan as "redo
    # this day" matches how attendance actually gets corrected in the field.
    #
    # The delete is scoped to method='omr' ONLY. This is load-bearing: an OMR re-scan must
    # never silently destroy a teacher's manual/app roll-call marks (method='app') for the
    # same date+class — those represent independent human judgement, not machine output the
    # OMR scan is entitled to overwrite. Order is delete-then-insert deliberately: if the
    # insert fails afterwards, the day is visibly empty (clearly broken) rather than holding
    # stale-but-wrong data from the previous scan.
    deleted_count = 0
    try:
        delete_resp = (
            _supabase
            .schema("attendance")
            .table("records")
            .delete()
            .eq("class_id", class_id)
            .eq("date", attendance_date)
            .eq("method", "omr")
            .execute()
        )
        deleted_count = len(delete_resp.data or [])
    except Exception as exc:
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"DB dedup-delete failed (cannot safely insert without clearing prior scan): {exc}",
        )

    # --- Insert into attendance.records via service-role (bypasses RLS) ---
    inserted_count = 0
    if records_to_insert:
        try:
            insert_resp = (
                _supabase
                .schema("attendance")
                .table("records")
                .insert(records_to_insert)
                .execute()
            )
            inserted_count = len(insert_resp.data or [])
        except Exception as exc:
            traceback.print_exc()
            raise HTTPException(status_code=500, detail=f"DB insert failed: {exc}")

    present_count = sum(1 for r in per_student_breakdown if r["status"] == "present" and not r["needs_review"])
    absent_count = sum(1 for r in per_student_breakdown if r["status"] == "absent" and not r["needs_review"])
    review_count = sum(1 for r in per_student_breakdown if r["needs_review"])

    return {
        "summary": {
            "total": len(raw_results),
            "present": present_count,
            "absent": absent_count,
            "needs_review": review_count,
        },
        "attendance_date": attendance_date,
        "class_id": class_id,
        "records": per_student_breakdown,
        "inserted": inserted_count,
        "replaced": deleted_count,
    }
