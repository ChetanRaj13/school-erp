# Security — School ERP

**Last updated:** 2026-08-14
**Scope:** Supabase project `yhcyhwpdgqupylrnkqht` ("smart-school-fintech", ap-south-1)

This document tracks the real, verified security posture of the project — what's been fixed,
what's known-open, and how findings get handled. Update it whenever a security-relevant issue
is found or fixed; don't let this drift the way the README did.

---

## 1. Fixed and verified

| Area | What was wrong | Fix |
|---|---|---|
| Row-level security | 7 tables had no RLS: `grades`, `submissions`, `class_roster`, `assignments`, `subjects`, `lesson_resources`, `messages` | RLS policies added and verified on all 7 |
| Anon-callable finance RPCs | `apply_late_fees` and `send_fee_reminders` were callable by unauthenticated clients | Locked down to authorized roles only |
| JWT claim bug | Code checked for a root-level `school_id` JWT claim that doesn't exist, silently blocking legitimate reads on 6 tables | Corrected to read the claim from its real location |
| Analytics role-scoping bypass | `analytics` schema's 8 `SECURITY DEFINER` functions checked `role NOT IN ('admin','principal')` — in Postgres, `NULL NOT IN (...)` evaluates to `NULL`, not `TRUE`, so an unauthenticated/roleless caller silently passed the check | Every role check wrapped in `coalesce(role, '')`; re-tested and confirmed blocking correctly |
| Razorpay web crash | `razorpay_flutter` (mobile SDK) was being invoked on a web build | Fixed; confirmed complete by the user |

## 2. Known open items — not yet fixed

**Storage bucket scoping** — `receipts`, `assignment-submissions`, and `lesson-resources`
buckets currently only check that a request is authenticated (logged in), not that the
requester owns the file or belongs to the right school. Exploitable only with a guessed or
leaked file path — real but lower urgency than the RLS items above. Flagged repeatedly across
sessions, never fixed. **Owner: unassigned.**

**RLS performance (borderline security/perf item)** — roughly 60 RLS policies re-evaluate
`auth.uid()`/`auth.jwt()` per row instead of once per query. Not a confidentiality issue by
itself, but worth tracking here too since it's the same policy surface — a slow policy under
load is more likely to get "temporarily" disabled or bypassed under pressure. See
`docs/tech_debt.md` for the full list.

**Broad read-access judgment calls** — `communications.messages` currently allows blanket
admin/principal read access, and `academic.announcements_read` / `public.schools` allow broad
`authenticated` read. These were deliberate calls made in session 1, not oversights, but
they've never been revisited. Worth a second look once the redesign work settles.

## 3. Data-generation caveat

The 3-year synthetic history (~156k rows) added a boolean `is_archived` flag and 6
historical-only classes. These were **not** covered by a fresh security review — the
assumption is they inherit the RLS posture of the real tables they were inserted into, but
that assumption hasn't been independently verified. Worth a targeted check before this data
is used in anything beyond analytics.

## 4. How findings get handled

1. Log it here immediately, even if the fix is deferred — an undocumented known-issue is
   worse than a documented one, since it can't be prioritized or handed off.
2. Note whether it's exploitable today (like the storage buckets) or requires implausible
   conditions — helps prioritize against feature work honestly.
3. Once fixed, move the row from "Known open items" to "Fixed and verified," and note how it
   was verified (re-run policy test, fetch live deployed code, re-derive the query result) —
   not just "fixed," since this project's history shows agent-reported fixes have needed
   independent re-verification more than once.
