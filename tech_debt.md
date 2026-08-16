# Tech Debt — School ERP

**Last updated:** 2026-08-14

Persistent, repo-level record of known-open work. Previously this only lived inside a
session-to-session chat handoff file, which meant it was invisible to anyone opening the repo
directly. Update this file whenever an item is resolved or a new one is found — don't let it
go stale the way `README.md` did.

---

## Open items

| Item | Detail | Urgency |
|---|---|---|
| `start-dev.ps1` untested | Script for one-command OMR + Flutter local startup was built, pushed, and verified correct by reading the file, but never actually executed end-to-end (no PowerShell access from the agent that built it) | Low — likely fine, needs one real run to confirm |
| `README.md` stale | Still the old "Post-Checkpoint Delivery" doc, doesn't reflect current setup (ports, Edge Functions, `start-dev.ps1`) | Medium — first thing anyone new reads |
| Dead files | `teacher_dashboard.dart`, `student_dashboard.dart`, `parent_dashboard.dart` are imported but unrouted; `.gitkeep`-only scaffold folders exist under `app/lib/features/` (`admissions/`, `attendance/`, `dashboards/`, `finance/`, `predictive_alerts/`, `timetable/`) | Low — cleanup, not a bug |
| Storage bucket scoping | See `SECURITY.md` — `receipts`, `assignment-submissions`, `lesson-resources` buckets check login status only, not ownership/school | Real but needs a leaked/guessed path to exploit |
| RLS performance | ~60 policies re-evaluate `auth.uid()`/`auth.jwt()` per row instead of once per query. Deliberately deferred repeatedly — real cost under load, not yet urgent enough to have blocked anything | Medium, grows with data volume |
| Pitch decks not committed | `docs/pitch_decks/` only has a placeholder `README.md`, no actual deck files | Low, but blocking if decks are needed soon |
| `document-extraction` service now dead code | Superseded by `document-extraction-trigger` + `document-commit` Edge Functions; the old FastAPI service is no longer called by the app but still sits in the repo | Low — safe to remove once confirmed unused elsewhere |
| Itemized fee-breakdown UI | `finance.invoice_line_items` schema has existed since an earlier session; no UI or data-population work has happened on top of it | Depends on whether this feature is still wanted |
| Visual redesign in progress | See `docs/design.md` — direction agreed, not yet implemented in the app | Active workstream |

## Recently resolved (keep for a few cycles, then prune)

- Archived-class UI leak across 9 files (fixed, verified via click-through)
- Docker port collision on `8003` (fixed, verified via `docker compose config`)
- Migration folder reconciliation — see `docs/schema.md` for the details
- Major local-vs-pushed git sync gap (found and resolved, most of a session's work)
- `server.py` hardcoded machine-specific path (fixed, now resolves relative to script location)

---

## Notes on process

- This file and `SECURITY.md` should be the durable source of truth for open work going
  forward — not a chat-handoff `.md` file that isn't part of the repo.
- When closing an item, move it to "Recently resolved" with a one-line note on how it was
  verified, not just that it was "done" — this project's history has repeatedly needed
  independent re-verification of agent-reported completions (see `CONTRIBUTING.md`).
