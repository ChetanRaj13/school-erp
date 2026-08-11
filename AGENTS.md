# AGENTS.md

## MANDATORY FIRST ACTION

Before responding to any user message in a new session, you MUST:

1. Read only the **top 2 entries** of `.agent-log/SESSION_LOG.md` (use `limit` — do not read the whole file).
2. Do NOT auto-open files those entries reference. Read a referenced file only if it is directly relevant to the current request.
Do this silently before your first reply.

---

## Project Context

This repo contains code for **two parallel hackathon submissions** built on a shared architecture:

1. **Smart School FinTech Innovation Challenge 2026** (organizer: PaperBuddy) — standalone fee management system: Dynamic Fee Engine, transaction/waiver/penalty tracking, omnichannel payments (UPI/card/netbanking + cash/cheque/DD reconciliation), animated glassmorphic admin dashboard (real-time revenue, defaulter tracking, revenue-breakdown charts).
2. **Future Ready Ops Innovation Challenge** — unified school ERP that *includes* module 1's finance system, plus: AI document processing (admission-form scan-to-database), timetable optimization (constraint solver + substitute recommendation), predictive resource allocation (absence/substitute forecasting), and dual-mode attendance (app roll-call + OMR scan).

Always confirm which challenge's code you're touching before making changes — features and deadlines differ, but both share the same underlying database and app shell.

**The public `README.md` in this repo is currently scoped to the FinTech Challenge submission only** — it does not mention the Future Ready Ops track. That's a submission-packaging decision, not an architecture change: the codebase itself still serves both challenges, and internal agent context (this file) should keep treating both as real.

## Architecture (do not deviate without explicit user approval)

* **Frontend**: Flutter + Riverpod (reactive state management), single codebase targeting mobile + web. Role-based routing — Principal / Admin / Teacher / Student / Parent share one app, different dashboards per role.
* **Backend/DB**: One Supabase (PostgreSQL) instance, project ref `yhcyhwpdgqupylrnkqht` (org `kaeslyxneffmlkhepxwj`, region ap-south-1). Separate **schemas** per domain — `finance.*`, `academic.*`, `staff.*`, `scheduling.*`, `attendance.*`, `documents.*` — linked via shared `students` / `staff` reference tables. Do NOT flatten these into one schema, and do NOT split into separate per-domain databases/microservices — this middle-ground was a deliberate, already-made decision. Note: attendance data lives in `attendance.records`, not `academic.attendance` — this exact mistake has already caused a production bug once (PGRST205, table not found); check the real schema name before writing any new query against attendance data.
* **Migration naming**: this project has moved to **timestamp-based migration filenames** (e.g. `20260725064817_description.sql`), not the older sequential `000X_description.sql` format. Any new migration must follow the timestamp convention. Do not create `000X`-numbered migration files — they will not match how this project's migration history actually reads, and have already caused confusion once (an agent claimed to create `0016`/`0017`/`0018` migrations that were never actually applied to the live database — see Verification Discipline below).
* **Row Level Security (RLS)**: every table needs a role-scoped policy — never expose cross-student or cross-staff data by default. Known current gap: `documents.admission_forms` has SELECT and UPDATE policies but they are role-only (admin/principal), with **no school-scoping** — any admin/principal at any school can currently read/update any other school's admission forms. This is intentional-for-now because `admission_forms.student_id` is nullable (forms not yet linked to a student), not yet fixed — flag to the user before doing unrelated RLS work on this table, since a real fix needs a design decision on how to scope unlinked forms, not just a query pattern change.
* **Payment balance updates**: `finance.increment_invoice_paid(p_invoice_id uuid, p_amount numeric)` is a live, verified `security definer` RPC function that atomically increments `finance.invoices.amount_paid`. Both the Razorpay webhook and the offline payment screen call this RPC. **Never reintroduce a read-then-write pattern** (select `amount_paid`, add in application code, then update) for any payment-balance code — that pattern caused a real race condition bug that was found and fixed. Any new code touching invoice balances must go through this RPC or an equivalent atomic SQL update.
* **Realtime**: use Supabase Realtime + Riverpod `StreamProvider` for anything that should update live on a dashboard (payments, attendance, substitutions). Don't build polling loops.
* **Payments**: Razorpay **Test Mode** only. Do not build a mock/dummy payment gateway — Razorpay's sandbox already provides dummy cards, UPI IDs, and real webhook payloads at no cost. Current status: the webhook-side confirmation flow (signature verification, idempotency, atomic balance update) is built and verified live. The client-side "Pay Online" trigger and server-side order-creation Edge Function are the remaining piece — "Pay Online" is intentionally disabled in the parent fees screen on web until this is finished. When building the order-creation endpoint, the order amount must be looked up from the invoice server-side, not trusted from the client.
* **Timetable solver**: Google OR-Tools (CP-SAT), run as a separate Python (FastAPI) microservice, called on demand — not a hand-rolled scheduling algorithm.
* **OMR attendance**: OpenCV + **ArUco markers** (not plain black-square corner detection) for perspective correction. Generator + scanner are already built and validated end-to-end (see `/omr_pipeline` — `generate_omr.py`, `scan_omr.py`, `test_pipeline.py`) — extend this, don't rewrite from scratch.
* **AI document extraction**: direct Vision-LLM structured-JSON extraction on the image. This is NOT a RAG use case (RAG is for semantic search/retrieval across many documents, not single-form field extraction) — do not reintroduce RAG for this step.
* **Human-in-the-loop**: any AI-extracted or auto-detected field (document OCR, ambiguous OMR bubbles) must pass through a review/confidence-flag step before being saved as final. Never auto-commit unreviewed AI output for records like DOB, fees, or attendance status.
* **UI direction (in progress)**: the visual redesign direction is decided — static background image (not video) with a slow Ken Burns drift, glassmorphic containers (`LiquidGlassContainer`), an Apple-style bottom dock nav (`AppleStyleDock`), expanding search bar, and a border-trail loading indicator for cards. Reference implementation lives in `lib/shared/widgets/` and has been wired into `parent_dashboard.dart` only so far. Principal, Admin, Teacher, and Student dashboards still use the older plain layout — apply the same pattern when asked, reusing the existing shared widgets rather than rebuilding them per screen. `google_fonts` (`Instrument Serif` + `Inter`) is the typography choice; don't introduce a different font package for this.
* **Deployment**: Flutter web build is deployed via Vercel. `build.sh` must call `flutter build web --release` — do not use `--web-renderer`, which was a valid flag on older Flutter versions but has been removed and will fail the Vercel build (`Command "bash build.sh" exited with 64`) on current Flutter.

## Verification Discipline

An agent has previously reported "all fixes applied and verified" when, on direct inspection of the live database, two of four claimed fixes were not actually present (a claimed RPC function didn't exist; a claimed migration file was never applied). Do not repeat this. Concretely:

* Don't report a database-side change as done without querying the live database (via the Supabase MCP connector, if connected) to confirm the table/policy/function actually exists as described.
* Don't assume a migration file existing locally means it was applied to the live project — check `list_migrations` or query `pg_policies`/`pg_proc` directly.
* If verification isn't possible in the current session, say so explicitly rather than reporting completion.

## Hard Rules

* Never modify system files without explicit instruction.
* Keep `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` in sync.
* Never commit sensitive information, API keys, or environment files.
* Do not invent gap-analysis figures or claims about PaperBuddy's existing product. The gap analysis came from a real audit of PaperBuddy's live demo app (48 screens across admin/teacher/student apps) — only use findings already documented in project notes; don't extrapolate new ones.
* Do not build a dummy/mock payment gateway — use Razorpay Test Mode.
* Do not use RAG for document field-extraction — use direct Vision-LLM extraction. RAG is reserved for a possible future cross-document search feature only, currently out of scope.
* Do not scope-creep attendance into RFID/face-recognition. Dual-mode (app + OMR) is the deliberate, infra-realistic scope for this build; hardware-dependent methods are future-scope only — mention, don't build.
* Stay within hackathon-realistic time budgets — flag to the user if a request would meaningfully expand build scope rather than silently taking it on.
* Never claim demo/test account passwords can be retrieved from the database — Supabase stores them hashed; there is no way to recover the plaintext. If the user needs to share demo credentials, that has to come from whoever originally set them.

## Cross-Agent Context Sharing

### Cover the Gemini gap

Gemini reads `GEMINI.md`; Claude Code reads `CLAUDE.md`. Keep all three identical:

```bash
cp AGENTS.md CLAUDE.md
cp AGENTS.md GEMINI.md
```

### Dynamic context (session log)

Append a 2–4 line entry to `.agent-log/SESSION_LOG.md` when you finish a task (newest at top): what changed, why, and any gotcha the next agent should know. Read the top 2 entries before starting work. Archive entries to `.agent-log/archive/` once the log grows past ~10 entries so it stays cheap to read.
