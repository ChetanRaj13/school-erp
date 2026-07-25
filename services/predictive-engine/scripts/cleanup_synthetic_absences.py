"""
cleanup_synthetic_absences.py — removes exactly the rows seed_synthetic_absences.py
inserted, using the saved seed_manifest.json (row ids, not a date-range guess) so this
can never accidentally delete real substitution data that happens to share a date range.

USAGE (from services/predictive-engine/, with venv activated):
    python scripts/cleanup_synthetic_absences.py

Run this before your final submission, or any time you want scheduling.substitutions
back to only-real-data state (e.g. before your teammate demos the Flutter substitutions
view, so they don't see fabricated rows).
"""

import json
import os
import sys
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


def main():
    if not MANIFEST_PATH.exists():
        print(f"No {MANIFEST_PATH} found — nothing to clean up (or it was already removed).")
        return

    manifest = json.loads(MANIFEST_PATH.read_text())
    ids = manifest.get("inserted_ids", [])
    print(f"Found manifest from {manifest.get('seeded_at')}: {len(ids)} synthetic rows to remove.")

    if not ids:
        print("Manifest has no ids — nothing to delete. Removing empty manifest file.")
        MANIFEST_PATH.unlink()
        return

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    # Delete in batches to stay well under any request size limits, though this dataset
    # is small enough that one batch would normally suffice.
    batch_size = 100
    deleted_total = 0
    for i in range(0, len(ids), batch_size):
        batch = ids[i:i + batch_size]
        supabase.schema("scheduling").table("substitutions").delete().in_("id", batch).execute()
        deleted_total += len(batch)

    print(f"✓ Deleted {deleted_total} synthetic rows from scheduling.substitutions.")

    MANIFEST_PATH.unlink()
    print(f"✓ Removed {MANIFEST_PATH}")
    print("scheduling.substitutions should now contain only real data again — verify with a direct query if in doubt.")


if __name__ == "__main__":
    main()
