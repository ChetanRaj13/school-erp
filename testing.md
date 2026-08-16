# Testing — School ERP

**Last updated:** 2026-08-14

What's actually tested today, and what isn't. Written to make gaps visible rather than
assumed away.

---

## What exists today

| File | Covers |
|---|---|
| `app/test/widget_test.dart` | Flutter widget-level tests |
| `app/test/omr_upload_screen_test.dart` | OMR upload screen |
| `test/razorpay_checkout_test.html` | Manual/browser-based Razorpay checkout flow check |
| `verify_fixes.py` | Ad-hoc verification script (root level) |
| `verify_screenshots/` | `01_splash.png`, `02_login.png` — reference screenshots, not automated |

There is no CI test gate beyond `.github/workflows/ci.yml` — check that workflow directly for
what it actually runs before assuming it covers more than the files above.

## Known gaps

- **No automated tests for RLS policies.** Every RLS fix and bug found so far (see
  `SECURITY.md`) was verified manually — by testing as a real user in the app, or by
  re-running the underlying query logic. None of that is codified as a repeatable test.
- **No automated tests for the `analytics` schema functions.** The 8 `SECURITY DEFINER`
  functions (attendance trend, grade trend, at-risk students, etc.) were verified once
  against real row counts for one specific teacher account. That verification isn't captured
  as a test that would catch a regression.
- **No automated tests for Edge Functions.** `document-extraction-trigger`, `document-commit`,
  `create-razorpay-order`, `razorpay-webhook`, `attendance-realtime-sync` are all verified
  manually or by diffing deployed code against intent — see `docs/edge_functions.md`. No
  integration test suite calls them.
- **No test coverage for the synthetic-history generator.** The real bugs caught during
  generation (`random()` caching, cross-year contamination, a transaction-rollback trap — see
  `docs/schema.md`) were all caught by manual inspection, not by a test that would catch a
  repeat of the same class of bug.
- **`start-dev.ps1` has never been executed** — see `docs/tech_debt.md`. Not a test gap
  exactly, but it means the one-command local setup path is unverified.

## Suggested priority if test investment happens

1. RLS policy tests — highest value, since this is the area that's already had a real,
   confirmed security bypass (the `NULL NOT IN (...)` bug).
2. Analytics function tests — second highest, since role-scoping bugs there have the same
   shape of risk as RLS bugs.
3. Edge Function integration tests, especially the Razorpay payment flow given it handles
   real money.
