"""
predictor.py — Predictive resource allocation: absence risk + resource-gap forecasting.

SCOPE (per AGENTS.md: "predictive resource allocation (absence/substitute forecasting)"):
This is a HYBRID forecaster: a rule-based frequency/statistical baseline below a data
threshold, and a logistic-regression model above it (see compute_absence_risk_hybrid and
_try_ml_absence_risk further down). The rule-based layer came first, and for good reason
— as of the last session, scheduling.substitutions had essentially zero real historical
rows (the only test row was created and then deleted during verification). A model
"trained" on that would have been fabricating confidence, so the original implementation
computed frequency-based risk from whatever real substitution history existed, degraded
gracefully to an explicit low-confidence baseline when it didn't, and reported its own
confidence level rather than hiding it. That reasoning still holds and is exactly why the
ML layer is gated behind a minimum total- and positive-sample count (ML_MIN_TOTAL_SAMPLES /
ML_MIN_POSITIVE_SAMPLES) instead of being used unconditionally: the logistic regression
only engages once there's enough real data to train on responsibly, and otherwise degrades
to the honest rule-based baseline rather than guessing. Every result carries
"method": "ml" | "rule_based" so the caller/UI can be transparent about which path produced
a given number.

VALUE PROPOSITION (why this earns its place over just "who might be absent"):
The actually useful output isn't "Teacher X has a 12% absence risk" in isolation — it's
"Teacher X is at elevated risk for Monday period 2, AND there is no qualified free
substitute for that slot" — i.e. surfacing coverage GAPS before they happen, so an admin
can pre-arrange coverage instead of scrambling. This is why /predict/resource-gaps calls
into the same free/qualified logic already built and verified in the timetable-solver's
substitute recommendation feature, rather than reinventing it.

SCHEMA — verified live via Supabase MCP against project yhcyhwpdgqupylrnkqht on 2026-07-23,
not guessed:
- scheduling.substitutions: id, original_teacher_id (uuid, NOT NULL), substitute_teacher_id
  (uuid, nullable), date (date, NOT NULL), slot_id (int4, NOT NULL, FK -> time_slots.id),
  class_id (uuid, NOT NULL), status (text, default 'proposed', check in
  proposed/confirmed/cancelled), created_at. 0 rows currently (test row was cleaned up).
- scheduling.timetable: id, class_id, subject_id, teacher_id, slot_id (FK -> time_slots.id),
  room_id (nullable), is_reviewed, reviewed_by, reviewed_at, created_at. 45 rows live.
- scheduling.time_slots: id (int4 PK), day (text, CHECK IN 'mon','tue','wed','thu','fri' —
  note: 3-letter lowercase, weekdays ONLY, no weekend rows exist at all), period_number
  (int4, 1-6), start_time, end_time. 30 rows (5 days x 6 periods).
- public.staff: id (uuid PK — NOT staff_id), school_id, full_name, role, max_periods
  (int4, default 20), monthly_salary, bank_account_last4.
- scheduling.teacher_subjects: id, teacher_id (FK staff.id), subject_id (FK subjects.id).
  Used by the existing /substitutes/recommend logic — this module does NOT reimplement
  qualification matching, it calls that existing endpoint (see main.py).
"""

from collections import defaultdict
from datetime import date, timedelta
from typing import Optional


# --- Confidence thresholds -------------------------------------------------
# Number of distinct historical weeks of substitution data observed for a given
# teacher+weekday combination, used to decide how much to trust the computed risk score.
MIN_WEEKS_FOR_MEDIUM_CONFIDENCE = 4
MIN_WEEKS_FOR_HIGH_CONFIDENCE = 10

# Baseline risk used when a teacher has zero substitution history at all. This is
# intentionally not 0.0 — a teacher with no recorded absences might just be new to the
# system, not literally never-absent. Flat baseline avoids false-confidence "0% risk".
BASELINE_RISK = 0.05


def _weekday_code(d: date) -> Optional[str]:
    """
    Returns the 3-letter lowercase weekday code matching scheduling.time_slots.day's real
    CHECK constraint (verified live: 'mon','tue','wed','thu','fri' only — no weekend rows
    exist in the schema at all, since there's no school on Sat/Sun). Returns None for
    Saturday/Sunday so callers can short-circuit cleanly instead of querying for rows that
    can never exist.
    """
    codes = ["mon", "tue", "wed", "thu", "fri", None, None]
    return codes[d.weekday()]


def compute_absence_risk(
    substitution_history: list[dict],
    teacher_ids: list[str],
    target_date: date,
    lookback_weeks: int = 12,
) -> list[dict]:
    """
    Compute an absence-risk score per teacher for a given target date, based on how often
    each teacher has historically appeared as original_teacher_id in scheduling.substitutions
    on the same weekday, within the lookback window.

    Args:
        substitution_history: rows from scheduling.substitutions with at least
            original_teacher_id, date, status. Status='cancelled' rows are excluded by
            the caller before passing in, or filtered here — see below.
        teacher_ids: all teacher ids to score (should include teachers with zero history,
            so they still get a baseline score rather than being silently omitted).
        target_date: the date being forecast for.
        lookback_weeks: how many weeks of history to consider "recent enough" to count.

    Returns:
        List of dicts, one per teacher, sorted by risk descending:
        {
            "teacher_id": ...,
            "risk_score": float 0.0-1.0,
            "confidence": "low" | "medium" | "high",
            "weeks_observed": int,
            "absences_on_this_weekday": int,
            "reason": plain-English string,
        }
    """
    target_weekday = _weekday_code(target_date)
    if target_weekday is None:
        # Weekend — no time_slots rows exist for Sat/Sun in this schema, so there is
        # nothing to forecast. Return baseline-everyone rather than erroring, so the
        # caller can decide how to surface "no school this day" to the admin.
        return [{
            "teacher_id": tid,
            "risk_score": 0.0,
            "confidence": "n/a",
            "method": "rule_based",
            "weeks_observed": 0,
            "absences_on_this_weekday": 0,
            "reason": "Weekend — no school day, no timetable slots exist for this date.",
        } for tid in teacher_ids]

    cutoff = target_date - timedelta(weeks=lookback_weeks)

    # Filter to real, non-cancelled absences within the lookback window, same weekday.
    relevant = [
        row for row in substitution_history
        if row.get("status") != "cancelled"
        and row.get("date")
        and cutoff <= row["date"] < target_date
        and _weekday_code(row["date"]) == target_weekday
    ]

    counts: dict[str, int] = defaultdict(int)
    for row in relevant:
        counts[row["original_teacher_id"]] += 1

    weeks_in_window = max(1, (target_date - cutoff).days // 7)

    results = []
    for tid in teacher_ids:
        n = counts.get(tid, 0)
        if n == 0:
            risk = BASELINE_RISK
            confidence = "low"
            reason = (
                f"No recorded '{target_weekday}' absences in the last "
                f"{lookback_weeks} weeks — baseline estimate used, not a real signal yet."
            )
        else:
            risk = min(1.0, n / weeks_in_window)
            confidence = (
                "high" if weeks_in_window >= MIN_WEEKS_FOR_HIGH_CONFIDENCE
                else "medium" if weeks_in_window >= MIN_WEEKS_FOR_MEDIUM_CONFIDENCE
                else "low"
            )
            reason = (
                f"Absent {n} of ~{weeks_in_window} observed '{target_weekday}'s "
                f"in the last {lookback_weeks} weeks."
            )
        results.append({
            "teacher_id": tid,
            "risk_score": round(risk, 3),
            "confidence": confidence,
            "method": "rule_based",
            "weeks_observed": weeks_in_window,
            "absences_on_this_weekday": n,
            "reason": reason,
        })

    results.sort(key=lambda r: r["risk_score"], reverse=True)
    return results


def _build_daily_dataset(
    substitution_history: list[dict],
    teacher_ids: list[str],
    target_date: date,
    lookback_weeks: int,
) -> list[dict]:
    """
    Builds a dense teacher x school-day training set: one row per (teacher, weekday) for
    every school day in the lookback window, labeled 1 if that teacher was actually
    absent that day (non-cancelled substitution row exists), else 0.

    This is what lets the ML model do something the pure rule-based approach can't: learn
    from the WHOLE staff's patterns at once (e.g. "Mondays have elevated absence school-
    wide") and apply that to a teacher who has zero individual history, rather than only
    ever looking at one teacher's own past in isolation.
    """
    cutoff = target_date - timedelta(weeks=lookback_weeks)
    absent_set = {
        (row["original_teacher_id"], row["date"])
        for row in substitution_history
        if row.get("status") != "cancelled" and row.get("date")
    }

    rows = []
    d = cutoff
    while d < target_date:
        code = _weekday_code(d)
        if code is not None:
            for tid in teacher_ids:
                rows.append({
                    "teacher_id": tid,
                    "weekday": code,
                    "label": 1 if (tid, d) in absent_set else 0,
                })
        d += timedelta(days=1)
    return rows


# Minimum total (teacher x day) samples before the ML model is even attempted. Below this,
# a logistic regression is more likely to overfit noise than learn anything real.
ML_MIN_TOTAL_SAMPLES = 40
# Minimum number of POSITIVE (actually-absent) samples required. A model trained on zero
# or near-zero positive examples degenerates to predicting near-0% for everyone, which is
# a worse failure mode than an honest "not enough data" fallback — so this is checked
# separately from total sample count.
ML_MIN_POSITIVE_SAMPLES = 6


def _try_ml_absence_risk(
    substitution_history: list[dict],
    teacher_ids: list[str],
    target_date: date,
    target_weekday: str,
    lookback_weeks: int,
) -> Optional[list[dict]]:
    """
    Attempts a logistic-regression-based forecast. Returns None (triggering fallback to
    rule-based) if scikit-learn isn't installed, if there isn't enough data yet, or if
    training fails for any reason — this must never crash the request, only degrade.
    """
    dataset = _build_daily_dataset(substitution_history, teacher_ids, target_date, lookback_weeks)
    total = len(dataset)
    positives = sum(r["label"] for r in dataset)

    if total < ML_MIN_TOTAL_SAMPLES or positives < ML_MIN_POSITIVE_SAMPLES:
        return None

    try:
        import numpy as np
        from sklearn.compose import ColumnTransformer
        from sklearn.linear_model import LogisticRegression
        from sklearn.pipeline import Pipeline
        from sklearn.preprocessing import OneHotEncoder
    except ImportError:
        # scikit-learn not installed in this environment — fall back silently rather than
        # crashing the endpoint. requirements.txt lists it, but this guard covers any
        # environment drift (e.g. a dev running an older venv).
        return None

    X = [[r["teacher_id"], r["weekday"]] for r in dataset]
    y = [r["label"] for r in dataset]

    try:
        pipeline = Pipeline([
            ("encode", ColumnTransformer([
                ("cat", OneHotEncoder(handle_unknown="ignore"), [0, 1]),
            ])),
            # NOTE: deliberately NOT using class_weight="balanced" here. It was tested
            # against synthetic data and badly over-inflated risk for teachers with only
            # random noise-level absences (0.68-0.78 for teachers who should score near
            # baseline) — on a small, highly imbalanced dataset like this, balancing
            # trades away calibration for recall on the minority class, which is the
            # wrong tradeoff for an advisory risk score an admin will read at face value.
            # Unweighted logistic regression stayed well-calibrated in the same test
            # (real pattern ~0.32, noise-only teachers ~0.07-0.18).
            ("clf", LogisticRegression(max_iter=1000)),
        ])
        pipeline.fit(X, y)
    except Exception:
        # Training can fail for edge-case reasons (e.g. a single class present despite the
        # positive-count guard, due to how sparse this data still is). Fall back rather
        # than 500ing the request.
        return None

    confidence = "high" if total >= ML_MIN_TOTAL_SAMPLES * 2 and positives >= ML_MIN_POSITIVE_SAMPLES * 2 else "medium"

    results = []
    for tid in teacher_ids:
        try:
            proba = pipeline.predict_proba([[tid, target_weekday]])[0]
            # predict_proba's column order follows the classes_ attribute; class 1 = absent.
            classes = list(pipeline.named_steps["clf"].classes_)
            risk = float(proba[classes.index(1)]) if 1 in classes else 0.0
        except Exception:
            risk = BASELINE_RISK
        results.append({
            "teacher_id": tid,
            "risk_score": round(risk, 3),
            "confidence": confidence,
            "method": "ml",
            "weeks_observed": lookback_weeks,
            "absences_on_this_weekday": None,
            "reason": (
                f"Logistic regression trained on {total} teacher-day samples "
                f"({positives} historical absences) across all staff — estimates risk "
                f"from both this teacher's pattern and school-wide '{target_weekday}' trends."
            ),
        })

    results.sort(key=lambda r: r["risk_score"], reverse=True)
    return results


def compute_absence_risk_hybrid(
    substitution_history: list[dict],
    teacher_ids: list[str],
    target_date: date,
    lookback_weeks: int = 12,
) -> list[dict]:
    """
    Hybrid dispatcher: uses the ML model once there's enough real substitution history to
    train on responsibly, otherwise falls back to the pure rule-based score. This is the
    function callers (main.py) should use — compute_absence_risk() is still exported
    directly for cases that explicitly want the rule-based-only behavior (e.g. tests).

    Every result carries "method": "ml" | "rule_based" so callers/UI can be transparent
    about which one produced a given number rather than presenting both as equally
    authoritative.
    """
    target_weekday = _weekday_code(target_date)
    if target_weekday is None:
        return compute_absence_risk(substitution_history, teacher_ids, target_date, lookback_weeks)

    ml_results = _try_ml_absence_risk(
        substitution_history, teacher_ids, target_date, target_weekday, lookback_weeks
    )
    if ml_results is not None:
        return ml_results

    return compute_absence_risk(substitution_history, teacher_ids, target_date, lookback_weeks)


def find_resource_gaps(
    risk_scores: list[dict],
    timetable_rows: list[dict],
    find_substitutes_fn,
    target_date: date,
    risk_threshold: float = 0.15,
) -> list[dict]:
    """
    Cross-reference at-risk teachers against their scheduled slots on target_date, and use
    the EXISTING substitute-recommendation logic (passed in as find_substitutes_fn, not
    reimplemented here) to check whether a qualified backup would actually be available if
    the risk materializes.

    Args:
        risk_scores: output of compute_absence_risk().
        timetable_rows: scheduling.timetable rows (teacher_id, class_id, subject_id,
            slot_id) for the weekday matching target_date.
        find_substitutes_fn: callable(teacher_id, target_date, slot_id) -> list[candidate]
            — MUST be the same function/logic backing POST /substitutes/recommend, imported
            or called directly, not duplicated. This is the integration point that makes
            this feature "resource-gap forecasting" rather than just "absence guessing".
        target_date: date being forecast.
        risk_threshold: only flag teacher/slot combos at or above this risk score, to avoid
            flooding the admin with low-signal baseline-risk noise.

    Returns:
        List of gap reports, most urgent first:
        {
            "teacher_id", "slot_id", "class_id", "subject_id",
            "risk_score", "confidence",
            "qualified_backup_available": bool,
            "candidate_count": int,
            "severity": "critical" | "watch",
            "note": plain-English summary,
        }
    """
    risk_by_teacher = {r["teacher_id"]: r for r in risk_scores}
    gaps = []

    for row in timetable_rows:
        tid = row.get("teacher_id")
        risk = risk_by_teacher.get(tid)
        if not risk or risk["risk_score"] < risk_threshold:
            continue

        candidates = find_substitutes_fn(tid, target_date, row["slot_id"]) or []
        qualified = [c for c in candidates if c.get("qualified")]

        has_backup = len(qualified) > 0
        severity = "critical" if not has_backup else "watch"
        note = (
            f"Elevated absence risk ({risk['risk_score']:.0%}, {risk['confidence']} "
            f"confidence) with {'NO qualified backup available' if not has_backup else f'{len(qualified)} qualified backup(s) available'}."
        )

        gaps.append({
            "teacher_id": tid,
            "slot_id": row.get("slot_id"),
            "class_id": row.get("class_id"),
            "subject_id": row.get("subject_id"),
            "risk_score": risk["risk_score"],
            "confidence": risk["confidence"],
            "qualified_backup_available": has_backup,
            "candidate_count": len(candidates),
            "severity": severity,
            "note": note,
        })

    # Critical (no backup) first, then by risk score descending.
    gaps.sort(key=lambda g: (g["severity"] != "critical", -g["risk_score"]))
    return gaps
