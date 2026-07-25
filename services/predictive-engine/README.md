# predictive-engine — Predictive Resource Allocation (absence/substitute forecasting)

## What this is

Rule-based (not ML) forecasting of teacher absence risk, cross-referenced against the
live timetable and real substitute availability, to surface staffing gaps *before* they
happen. Advisory only — never writes to the database.

Built to slot in as `services/predictive-engine/` alongside `services/timetable-solver/`
and `services/omr-pipeline/`, matching the existing project structure per
`project_context_brief.md`.

## Why rule-based, not ML

As of the last session, `scheduling.substitutions` has essentially no real historical
data — the only row created was a test row, which was deleted during verification. A
model "trained" on that would be fabricating confidence it doesn't have. This instead:
- Computes real frequency-based risk from whatever history *does* exist
- Falls back to an explicit, clearly-labeled baseline for teachers with no history
- Reports its own confidence level (low/medium/high based on weeks observed) so nobody
  mistakes a baseline guess for a real signal

This is an honest, defensible scope for a hackathon build — and it's easy to swap the
scoring function for a real model later without touching the API shape, once there's
actually enough substitution history to train on.

## Placement

```
school-erp/
  services/
    predictive-engine/       <- this folder
      main.py
      predictor.py
      requirements.txt
      .env                    <- create this, don't commit it (see below)
    timetable-solver/
    omr-pipeline/
```

## Setup

```powershell
cd services\predictive-engine
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
```

Create `.env` in this folder (same pattern as `timetable-solver/.env` — copy the
`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` values from there):

```
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
TIMETABLE_SOLVER_URL=http://localhost:8003
```

Run (on a different port from timetable-solver, which uses 8003):

```powershell
python -m uvicorn main:app --port 8004
```

## Schema — verified live, not guessed

Pulled directly from your Supabase project (`yhcyhwpdgqupylrnkqht`) via the Supabase MCP
connector on 2026-07-23 — this replaces an earlier draft of this file that was written
from session-log descriptions alone:

- `public.staff`: PK is `id` (not `staff_id`), plus `school_id`, `full_name`, `role`,
  `max_periods` (default 20).
- `scheduling.timetable`: `id, class_id, subject_id, teacher_id, slot_id, room_id,
  is_reviewed, reviewed_by, reviewed_at, created_at`. 45 rows live.
- `scheduling.substitutions`: `id, original_teacher_id, substitute_teacher_id (nullable),
  date, slot_id, class_id, status (proposed/confirmed/cancelled), created_at`. 0 rows
  currently (test row was cleaned up after verification).
- `scheduling.time_slots`: `id` (PK — timetable/substitutions reference it as `slot_id`
  via FK), `day` (**3-letter lowercase: 'mon','tue','wed','thu','fri' — weekdays only,
  no Saturday/Sunday rows exist in this schema at all**), `period_number` (1-6),
  `start_time`, `end_time`. 30 rows (5 days × 6 periods).
- `scheduling.teacher_subjects`: `id, teacher_id, subject_id`.

The code in this folder has been updated to match this exactly — the earlier
`monday`/`tuesday` full-name guess and `staff_id` guess were both wrong and are fixed.

## Still worth verifying before trusting this code (real gaps, not guesses)

1. **`_safe_fetch` and `find_substitutes` in `main.py` are standalone** — written to
   match the patterns described in `SESSION_LOG.md`, but not checked against the actual
   `services/timetable-solver/main.py` source (I don't have that file). If a
   `_safe_fetch` helper already exists there, reuse it instead of running two copies
   that can drift — the finance-schema divergence earlier in this project is exactly
   the failure mode to avoid here.

2. **`find_substitutes`'s HTTP call shape to `/substitutes/recommend`** is inferred from
   the session log's description (`{teacher_id, date, slot_id}` in, `{candidates: [...]}`
   with a `qualified` bool out) — confirm the real request/response shape against the
   actual endpoint code before trusting it end to end.

3. **RLS finding worth knowing about, unrelated to this service**: `scheduling.timetable`
   and `scheduling.substitutions` both use a broad `auth.role() = 'authenticated'` SELECT
   policy — any authenticated user can read all schools' data, unlike `public.staff`
   which is properly school-scoped (`school_id = auth.jwt()->>'school_id'`). Not urgent
   for a single-school demo, worth tightening before any real multi-school deployment.

4. **Test with real data before trusting output**: `scheduling.substitutions` currently
   has 0 real rows, so every teacher will return `confidence: "low"` and the baseline
   risk score until real absence data accumulates from actual substitute-commit usage.
   That's expected — verify the endpoint *behaves* correctly (sane baseline output, no
   crash on empty history) rather than expecting meaningful risk numbers yet.

## Hybrid: rule-based + ML

This is now a genuine hybrid, not pure rule-based:

- **Below the data threshold** (currently: fewer than 40 total teacher-day samples in the
  lookback window, or fewer than 6 actual historical absences), it uses the rule-based
  frequency score — same as before, honest baseline for teachers/days with no signal.
- **Above the threshold**, it trains a logistic regression (scikit-learn) on the fly —
  retraining per request, since the dataset stays small enough (tens to low hundreds of
  rows) that this is cheap, and it means the model is always current, no stale model file
  to manage.
- Every result carries `"method": "ml"` or `"method": "rule_based"` so the admin (and you,
  demoing it) can see exactly which one produced a given number — no pretending the
  baseline estimate is a trained prediction, or vice versa.

**Why this is actually a better answer than rule-based alone, not just a fancier one**: the
ML model trains across *all* teachers at once, so it can say something meaningful about a
teacher with zero individual absence history, by learning school-wide patterns (e.g. "this
school has elevated Monday absences generally"). The pure per-teacher rule-based score
can never do that — a teacher with no history always gets the flat baseline, full stop.

### Calibration note (found by testing, not assumed)

The first version used `class_weight="balanced"` in the logistic regression, which is a
common default for imbalanced classification. Tested against synthetic data, it badly
over-inflated risk for teachers with only random noise-level absences — 0.68 to 0.78 for
teachers who should score near baseline, versus 0.32 for the teacher with an actual
seeded pattern. That's the wrong tradeoff for a risk score an admin reads at face value —
balancing optimizes for catching the minority class, not for producing a trustworthy
probability. Switched to unweighted logistic regression, which stayed well-calibrated in
the same test (real pattern ~0.32, noise-only teachers ~0.07-0.18, correctly ranked).

This is exactly the kind of thing to sanity-check yourself too before demoing — feed it
some synthetic data with a known pattern and confirm the ranking makes sense, the same
way this was tested here.

### Testing the ML path yourself

`scheduling.substitutions` has 0 real rows right now, so out of the box every forecast
will use `method: "rule_based"`. To see the ML path activate, you'd need either real usage
data to accumulate, or to seed synthetic historical rows for a demo. I can build a seeding
script for that if useful — just ask.

## Endpoints

### `POST /predict/absence-risk`
```json
{ "target_date": "2026-08-03", "lookback_weeks": 12 }
```
Returns every teacher ranked by absence risk for that date, with confidence level and
plain-English reasoning per teacher.

### `POST /predict/resource-gaps`
```json
{ "target_date": "2026-08-03", "lookback_weeks": 12, "risk_threshold": 0.15 }
```
The higher-value endpoint: cross-references at-risk teachers against their actual
scheduled slots that day, and checks real substitute availability for each, returning
gaps ranked `critical` (no qualified backup) first, then `watch`.

## Not built (explicitly out of scope for this pass)

- Any UI beyond the throwaway test harness (`predictive-test-harness.html`) — same
  pattern as the OMR/Razorpay/timetable harnesses, not part of the real Flutter app.
- Deployment — per your own instruction, batched as one task closer to submission.
- Real ML forecasting — implemented above as a hybrid layer, see "Hybrid: rule-based + ML".
