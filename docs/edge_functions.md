# Supabase Edge Functions — School ERP

**Last updated:** 2026-08-14

Backend-of-record functions deployed to the Supabase project. This app is intentionally
server-free for everything except the OMR pipeline (see note at the bottom) — these functions
are the real backend for the features they cover.

---

## Deployed functions

| Function | Purpose | Notes |
|---|---|---|
| `attendance-realtime-sync` | Keeps attendance state in sync in real time | Pre-existing, not touched in the most recent redesign session |
| `create-razorpay-order` | Creates a Razorpay order for online fee payment | Confirmed working end-to-end; the earlier web-build crash was in the Flutter client, not this function |
| `razorpay-webhook` | Receives Razorpay payment confirmation callbacks | Pre-existing |
| `document-extraction-trigger` | Takes a base64-encoded image, calls an OpenRouter vision LLM, writes extracted fields to the DB | **v2** — rewritten to accept JSON with a base64 image, matching the Supabase Flutter SDK's `functions.invoke()` pattern. Zero local image processing. |
| `document-commit` | Commits a reviewed/approved extraction to its final destination table | New — built alongside the `document-extraction-trigger` rewrite |
| `omr-scan` | Takes a base64-encoded OMR attendance sheet image, scans bubble marks via Vision-LLM, reconciles with class roster, and persists to `attendance.records` | Supports zero-server client workflow with instant review flag resolution. |

## Deployment notes

- Manual CLI deploy is the reliable path for this project — in-chat deploy-approval flows have
  not worked reliably in past sessions. Don't assume a deploy succeeded from a chat
  confirmation; verify by fetching the live deployed code back and diffing it against intent.
- When in doubt about whether a function is actually live and current, fetch the deployed
  source directly rather than trusting the last deploy command's reported success.

## Superseded / no longer called

`services/document-extraction/` (the original FastAPI microservice) is superseded by the two
functions above and is no longer called by the live app. It's still physically in the repo —
see `docs/tech_debt.md` for the cleanup item.

## Related local (non-Edge-Function) services

These are NOT Edge Functions — they're local-only FastAPI microservices, listed here only to
avoid confusion with the table above:

| Service | Port | Status |
|---|---|---|
| `omr-pipeline` | 8002 | Genuinely can't be ported — real OpenCV/ArUco computer vision. Kept local by deliberate choice, wrapped in `start-dev.ps1` for one-command startup. |
| `timetable-solver` | 8003 | Local-only, respects `is_archived` (won't schedule fictional/historical classes) |
| `predictive-engine` | 8004 | Local-only, not wired up yet — the synthetic history generation backfilled ~895 real substitution rows with per-teacher patterns, so there's now real signal available if this gets wired up |
