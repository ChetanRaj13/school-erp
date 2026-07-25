"""
seed_synthetic_absences.py — inserts synthetic historical rows into scheduling.substitutions
so the predictive-engine's ML path (which needs real data to train on) actually activates
for a demo, instead of always falling back to the rule-based baseline.

WHAT THIS DOES: picks one real teacher who has real Monday timetable assignments, and
backfills ~16 weeks of synthetic past Mondays where that teacher was "absent" (a
scheduling.substitutions row with status='confirmed'), at ~60% frequency. Every other
teacher gets a light random background rate (~3%) so the model has real negative examples
too, not just one obvious signal. This mirrors exactly the synthetic pattern used to test
predictor.py's calibration before this script existed.

WHY THIS APPROACH, NOT RANDOM DATA ACROSS ALL TEACHERS/DAYS: a demo is more convincing (and
easier to verify by eye) if there's one clear, explainable story — "Suresh is often out on
Mondays, the model correctly flags him as high-risk, and here's why" — rather than diffuse
noise that's hard to sanity-check at a glance.

SAFETY:
- Every inserted row's id is written to seed_manifest.json in this folder. Run
  cleanup_synthetic_absences.py before your final submission (or before anyone inspects
  scheduling.substitutions expecting only real data) — it deletes exactly these rows and
  nothing else, using the saved ids, not a date-range guess.
- Refuses to run if seed_manifest.json already exists, to avoid double-seeding or losing
  track of a previous batch — delete or rename the file (or run cleanup first) if you
  intend to reseed.
- --dry-run prints exactly what would be inserted without writing anything.
- class_id and slot_id for each synthetic row are pulled from the teacher's REAL
  scheduling.timetable assignment for that weekday — so every synthetic row is internally
  consistent with your real schema (the teacher genuinely does teach that class at that
  slot on that weekday in your live timetable), not fabricated combinations.

USAGE (from services/predictive-engine/, with venv activated):
    python scripts/seed_synthetic_absences.py --dry-run     # preview only
    python scripts/seed_synthetic_absences.py               # actually insert
    python scripts/cleanup_synthetic_absences.py             # remove exactly what was seeded
"""

import argparse
import json
import os
import random
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SCRIPT_DIR = Path(__file__).parent
MANIFEST_PATH = SCRIPT_DIR / "seed_manifest.json"

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
    print("ERROR: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set in .env — same file main.py uses.")
    sys.exit(1)

TARGET_WEEKDAY_INDEX = 0  # Monday (Python's date.weekday(): Mon=0 ... Fri=4)
TARGET_WEEKDAY_CODE = "mon"
TARGET_ABSENCE_PROBABILITY = 0.60
BACKGROUND_ABSENCE_PROBABILITY = 0.03
LOOKBACK_WEEKS = 16
RANDOM_SEED = 42  # fixed seed so a --dry-run preview matches the real run exactly


def get_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def pick_target_teacher(supabase: Client, timetable_rows: list[dict]) -> str | None:
    """
    Picks whichever teacher has the most Monday timetable assignments, so the synthetic
    absence pattern has real recurring slots to attach to. Returns None if nobody teaches
    on Mondays at all (would mean your seed data doesn't support this demo pattern).
    """
    monday_rows = [r for r in timetable_rows if r.get("_weekday_code") == TARGET_WEEKDAY_CODE]
    if not monday_rows:
        return None
    counts: dict[str, int] = {}
    for r in monday_rows:
        counts[r["teacher_id"]] = counts.get(r["teacher_id"], 0) + 1
    return max(counts, key=counts.get)


def build_synthetic_rows(
    timetable_rows: list[dict],
    teacher_ids: list[str],
    target_teacher_id: str,
) -> list[dict]:
    """
    For every school day in the lookback window, for every teacher who has a real
    timetable assignment that weekday, roll the dice on whether they were "absent" that
    day. target_teacher_id gets the elevated Monday-only probability; everyone else
    (including the target teacher on non-Mondays) gets the light background rate.
    """
    random.seed(RANDOM_SEED)
    today = date.today()
    cutoff = today - timedelta(weeks=LOOKBACK_WEEKS)

    rows_by_teacher_weekday: dict[tuple[str, str], list[dict]] = {}
    for r in timetable_rows:
        key = (r["teacher_id"], r["_weekday_code"])
        rows_by_teacher_weekday.setdefault(key, []).append(r)

    synthetic = []
    d = cutoff
    while d < today:
        weekday_code = _weekday_code(d)
        if weekday_code is not None:
            for tid in teacher_ids:
                assignments = rows_by_teacher_weekday.get((tid, weekday_code))
                if not assignments:
                    continue  # teacher doesn't teach that weekday at all — nothing to seed
                is_target_day = (tid == target_teacher_id and weekday_code == TARGET_WEEKDAY_CODE)
                p = TARGET_ABSENCE_PROBABILITY if is_target_day else BACKGROUND_ABSENCE_PROBABILITY
                if random.random() < p:
                    # Real teachers often teach multiple periods the same day — pick ONE
                    # real assignment for that day to be "absent" from, not all of them,
                    # to keep the synthetic data realistic (one absence record per day).
                    assignment = random.choice(assignments)
                    synthetic.append({
                        "original_teacher_id": tid,
                        "date": d.isoformat(),
                        "slot_id": assignment["slot_id"],
                        "class_id": assignment["class_id"],
                        "status": "confirmed",
                        "substitute_teacher_id": None,
                    })
        d += timedelta(days=1)
    return synthetic


def _weekday_code(d: date) -> str | None:
    codes = ["mon", "tue", "wed", "thu", "fri", None, None]
    return codes[d.weekday()]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Preview without inserting")
    args = parser.parse_args()

    if MANIFEST_PATH.exists() and not args.dry_run:
        print(f"ERROR: {MANIFEST_PATH} already exists — a previous seed batch may still be live.")
        print("Run cleanup_synthetic_absences.py first, or delete the manifest if you're sure.")
        sys.exit(1)

    supabase = get_client()

    print("Fetching real staff and timetable data...")
    staff_rows = supabase.schema("public").table("staff").select("id, full_name").execute().data
    teacher_ids = [s["id"] for s in staff_rows]
    id_to_name = {s["id"]: s["full_name"] for s in staff_rows}

    timetable_raw = supabase.schema("scheduling").table("timetable").select("*").execute().data
    time_slots = supabase.schema("scheduling").table("time_slots").select("id, day").execute().data
    slot_id_to_day = {s["id"]: s["day"] for s in time_slots}

    timetable_rows = []
    for r in timetable_raw:
        day = slot_id_to_day.get(r["slot_id"])
        if day:
            r["_weekday_code"] = day
            timetable_rows.append(r)

    target_teacher_id = pick_target_teacher(supabase, timetable_rows)
    if not target_teacher_id:
        print("ERROR: no teacher has a Monday timetable assignment — nothing to seed against.")
        sys.exit(1)

    target_name = id_to_name.get(target_teacher_id, target_teacher_id)
    print(f"Target teacher for elevated Monday absence pattern: {target_name} ({target_teacher_id})")

    synthetic_rows = build_synthetic_rows(timetable_rows, teacher_ids, target_teacher_id)
    target_count = sum(1 for r in synthetic_rows if r["original_teacher_id"] == target_teacher_id)
    other_count = len(synthetic_rows) - target_count

    print(f"\nWould insert {len(synthetic_rows)} synthetic substitution rows:")
    print(f"  {target_count} for {target_name} (elevated Monday pattern)")
    print(f"  {other_count} background noise rows across other teachers/days")

    if args.dry_run:
        print("\n--dry-run: nothing was inserted. Sample of first 5 rows:")
        for r in synthetic_rows[:5]:
            print(f"  {r}")
        return

    print("\nInserting...")
    result = supabase.schema("scheduling").table("substitutions").insert(synthetic_rows).execute()
    inserted_ids = [row["id"] for row in result.data]

    manifest = {
        "seeded_at": datetime.utcnow().isoformat() + "Z",
        "target_teacher_id": target_teacher_id,
        "target_teacher_name": target_name,
        "row_count": len(inserted_ids),
        "inserted_ids": inserted_ids,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2))

    print(f"✓ Inserted {len(inserted_ids)} rows. Manifest saved to {MANIFEST_PATH}")
    print("  Run cleanup_synthetic_absences.py before final submission to remove this synthetic data.")
    print(f"\n  Now try POST /predict/absence-risk with target_date on a Monday (e.g. next Monday)")
    print(f"  — {target_name} should show method:\"ml\" with an elevated risk_score.")


if __name__ == "__main__":
    main()
