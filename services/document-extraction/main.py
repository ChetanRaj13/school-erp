"""Document Extraction Service — FastAPI microservice.

POST /documents/extract  — Vision-LLM extraction, stores draft, returns for human review.
POST /documents/commit   — Persists admin-reviewed fields to public.students.

Human-in-the-loop: /extract never writes to students. /commit requires explicit admin input.
Uses service-role key (bypasses RLS). Same pattern as timetable-solver/main.py.

Start with:
    uvicorn main:app --reload --port 8005
"""

import os
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from supabase import create_client, Client

from extractor import extract_fields

# Load from service directory first (per-service .env convention)
_env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=_env_path, override=True)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
DEMO_SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    raise RuntimeError(
        f"SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY must be set in {_env_path}"
    )

_supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def _safe_fetch(query_fn):
    try:
        return query_fn(), None
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        return None, str(exc)


app = FastAPI(title="Document Extraction Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)


class CommitRequest(BaseModel):
    form_id: str
    # Admin-reviewed values — only fields present here are written to students
    full_name: str | None = None
    admission_number: str | None = None
    guardian_contact: str | None = None
    # Link to existing student or create new
    student_id: str | None = None


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/documents/extract")
async def extract(file: UploadFile = File(...)):
    """Accept an admission-form image, run Vision-LLM extraction, store draft.

    Returns the draft form_id + all extracted fields with confidence scores.
    Nothing is written to public.students — human review required before /commit.
    Fields with confidence < 0.7 are listed in uncertain_fields.
    """
    image_bytes = await file.read()
    mime_type = file.content_type or "image/jpeg"

    try:
        result = extract_fields(image_bytes, mime_type)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"LLM extraction failed: {exc}")

    fields = result["fields"]
    uncertain = result["uncertain_fields"]

    # Store draft — status stays pending_review until /commit
    insert_resp, err = _safe_fetch(
        lambda: _supabase.schema("documents").table("admission_forms").insert({
            "original_image_url": file.filename or "uploaded",
            "extracted_json": fields,
            "uncertain_fields": uncertain,
            "status": "pending_review",
            "extracted_by": result.get("model_used", "ai"),
        }).execute()
    )
    if err or not insert_resp.data:
        raise HTTPException(status_code=500, detail=f"Failed to store draft: {err}")

    form = insert_resp.data[0]
    return {
        "form_id": form["id"],
        "fields": fields,
        "uncertain_fields": uncertain,
        "model_used": result.get("model_used"),
        "status": "pending_review",
    }


@app.post("/documents/commit")
def commit(req: CommitRequest):
    """Persist admin-reviewed fields to public.students.

    Human-in-the-loop: only fields explicitly provided in the request are written.
    Creates a new student if student_id is omitted; updates existing if provided.
    Marks the form verified + links student_id.
    """
    # Verify form exists and is pending
    form_resp, err = _safe_fetch(
        lambda: _supabase.schema("documents").table("admission_forms")
            .select("*").eq("id", req.form_id).execute()
    )
    if err:
        raise HTTPException(status_code=500, detail=f"Form fetch failed: {err}")
    if not form_resp.data:
        raise HTTPException(status_code=404, detail=f"form_id {req.form_id} not found.")
    form = form_resp.data[0]
    if form["status"] != "pending_review":
        raise HTTPException(
            status_code=409,
            detail=f"Form already {form['status']} — cannot re-commit.",
        )

    # Build student payload from only the fields the admin confirmed
    student_payload = {}
    if req.full_name is not None:
        student_payload["full_name"] = req.full_name
    if req.admission_number is not None:
        student_payload["admission_number"] = req.admission_number
    if req.guardian_contact is not None:
        student_payload["guardian_contact"] = req.guardian_contact

    if not student_payload:
        raise HTTPException(
            status_code=400,
            detail="At least one of full_name, admission_number, guardian_contact required.",
        )

    reviewed_at = datetime.now(timezone.utc).isoformat()

    if req.student_id:
        # Update existing student
        upd_resp, err = _safe_fetch(
            lambda: _supabase.table("students")
                .update(student_payload).eq("id", req.student_id).execute()
        )
        if err:
            raise HTTPException(status_code=500, detail=f"Student update failed: {err}")
        if not upd_resp.data:
            raise HTTPException(status_code=404, detail=f"student_id {req.student_id} not found.")
        student_id = req.student_id
    else:
        # New student — school_id is NOT NULL, wire in demo school
        if "full_name" not in student_payload or "admission_number" not in student_payload:
            raise HTTPException(
                status_code=400,
                detail="full_name and admission_number required to create a new student.",
            )
        student_payload["school_id"] = DEMO_SCHOOL_ID
        ins_resp, err = _safe_fetch(
            lambda: _supabase.table("students").insert(student_payload).execute()
        )
        if err:
            raise HTTPException(status_code=500, detail=f"Student insert failed: {err}")
        student_id = ins_resp.data[0]["id"]

    # Mark form verified
    _safe_fetch(
        lambda: _supabase.schema("documents").table("admission_forms").update({
            "status": "verified",
            "student_id": student_id,
            "reviewed_at": reviewed_at,
        }).eq("id", req.form_id).execute()
    )

    return {
        "status": "committed",
        "student_id": student_id,
        "form_id": req.form_id,
        "reviewed_at": reviewed_at,
    }
