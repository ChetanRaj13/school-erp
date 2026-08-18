# Database Schema Reference — School ERP

**Last updated:** 2026-08-14
**Supabase project:** `yhcyhwpdgqupylrnkqht` ("smart-school-fintech", ap-south-1)

Migration numbering has already caused real collisions in this project more than once. This
file exists so the next person adding a migration checks here first instead of guessing the
next free number from what's in their local branch.

---

## 1. Real current migration sequence

`0001 – 0003, 0005 – 0019` — **`0004` is correctly absent** (it created a schema that doesn't
exist live; confirmed dead and removed, not a gap to fill).

| File | Notes |
|---|---|
| `0001–0003` | Not individually audited in the latest verification pass |
| `0002_finance_schema.sql` | Restored to its original 1-line stub — the real finance schema now lives in `0019` |
| `0005–0008` | Not individually audited in the latest verification pass |
| `0009_auth_linkage.sql` | Lives at repo-root `supabase/migrations/` — was previously miscopied into a nested `app/supabase/migrations/` path; that nested copy no longer exists |
| `0013_baseline_reconciliation.sql` | Schools, parent_links, notifications, staff_attendance, academic.* gaps, communications.messages, audit.log, enums, corrected students/staff |
| `0014_invoice_line_items.sql` | Pre-existing, itemized fee-breakdown schema — **unrelated** to the `0019` finance export below despite the numbering being close; don't assume they're linked |
| `0015–0018` | Pre-existing, not individually audited. **`0018` is used twice by two different legitimate files** — a pre-existing quirk, not a bug to fix |
| `0019_finance_schema.sql` | The real finance schema export — originally slated to be `0014` until that number turned out to already be taken by the unrelated invoice-line-items migration above, so it was renamed to the next real free slot |

**Before adding a new migration:** check this table's actual file list against what's really
in the repo (`git log` / fresh clone), not just the highest number you see locally — this
project has hit numbering collisions from stale local state more than once.

---

## 2. Schema additions from the synthetic-history generation

Added to power analytics and a standalone historical analysis; not part of the original
feature schema.

- `academic.classes.is_archived` (boolean, default `false`) — did not touch the 10 real
  classes, only the historical-only ones below
- 6 new historical-only classes: `3-A/B`, `4-A/B`, `5-A/B`, with subjects copied from the real
  9-subject-per-class pattern
- `academic.class_roster_history` (`student_id`, `class_id`, `academic_year`) — used only by
  the data generator and the analytics functions below; never read directly by the live app

~156,000 rows generated across attendance, grades, assignments/submissions, finance
(fee_structures/invoices/payments/payroll/budgets/purchase_orders/vendor_payments),
leave_requests, scheduling.substitutions, and admission_forms, covering 3 prior academic years
(2023-24, 2024-25, 2025-26).

## 3. `analytics` schema

8 `SECURITY DEFINER` functions, each doing its own internal role-scoping (admin/principal see
school-wide data, teachers see only their own classes — see `SECURITY.md` for the role-check
bug that was found and fixed here):

- Attendance trend
- Grade trend
- At-risk students
- Attendance-grade correlation
- Cohort comparison
- Revenue trend
- Budget variance
- Admission trend

## 4. Known Postgres gotchas hit in this project

Worth remembering before writing new migrations or generation scripts against this database:

- **`random()` in a subquery/LATERAL can get cached, not evaluated fresh per row.** Bit a
  "chronic student" flag (came back `true` for all 600 rows) and an admission-year
  distribution (all landed in one year) — fixed by moving `random()` directly into the main
  `SELECT` list instead of a wrapped subquery.
- **`CREATE TABLE AS INSERT ... RETURNING` is not valid syntax** — needs a CTE instead.
- **Array indexing needs an explicit `::int` cast** — `floor()` alone isn't enough.
- **`NULL NOT IN (...)` evaluates to `NULL`, not `TRUE`, in Postgres** — any role/permission
  check written as a bare `NOT IN` needs `coalesce(..., '')` or equivalent, or an
  unauthenticated/roleless caller silently passes.
