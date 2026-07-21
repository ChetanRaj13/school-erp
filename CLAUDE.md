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

## Architecture (do not deviate without explicit user approval)
- **Frontend**: Flutter + Riverpod (reactive state management), single codebase targeting mobile + web. Role-based routing — Principal / Admin / Teacher / Student / Parent share one app, different dashboards per role.
- **Backend/DB**: One Supabase (PostgreSQL) instance. Separate **schemas** per domain — `finance.*`, `academic.*`, `staff.*`, `scheduling.*`, `attendance.*`, `documents.*` — linked via shared `students` / `staff` reference tables. Do NOT flatten these into one schema, and do NOT split into separate per-domain databases/microservices — this middle-ground was a deliberate, already-made decision.
- **Row Level Security (RLS)**: every table needs a role-scoped policy — never expose cross-student or cross-staff data by default.
- **Realtime**: use Supabase Realtime + Riverpod `StreamProvider` for anything that should update live on a dashboard (payments, attendance, substitutions). Don't build polling loops.
- **Payments**: Razorpay **Test Mode** only. Do not build a mock/dummy payment gateway — Razorpay's sandbox already provides dummy cards, UPI IDs, and real webhook payloads at no cost.
- **Timetable solver**: Google OR-Tools (CP-SAT), run as a separate Python (FastAPI) microservice, called on demand — not a hand-rolled scheduling algorithm.
- **OMR attendance**: OpenCV + **ArUco markers** (not plain black-square corner detection) for perspective correction. Generator + scanner are already built and validated end-to-end (see `/omr_pipeline` — `generate_omr.py`, `scan_omr.py`, `test_pipeline.py`) — extend this, don't rewrite from scratch.
- **AI document extraction**: direct Vision-LLM structured-JSON extraction on the image. This is NOT a RAG use case (RAG is for semantic search/retrieval across many documents, not single-form field extraction) — do not reintroduce RAG for this step.
- **Human-in-the-loop**: any AI-extracted or auto-detected field (document OCR, ambiguous OMR bubbles) must pass through a review/confidence-flag step before being saved as final. Never auto-commit unreviewed AI output for records like DOB, fees, or attendance status.

## Hard Rules
- Never modify system files without explicit instruction.
- Keep `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md` in sync.
- Never commit sensitive information, API keys, or environment files.
- Do not invent gap-analysis figures or claims about PaperBuddy's existing product. The gap analysis came from a real audit of PaperBuddy's live demo app (48 screens across admin/teacher/student apps) — only use findings already documented in project notes; don't extrapolate new ones.
- Do not build a dummy/mock payment gateway — use Razorpay Test Mode.
- Do not use RAG for document field-extraction — use direct Vision-LLM extraction. RAG is reserved for a possible future cross-document search feature only, currently out of scope.
- Do not scope-creep attendance into RFID/face-recognition. Dual-mode (app + OMR) is the deliberate, infra-realistic scope for this build; hardware-dependent methods are future-scope only — mention, don't build.
- Stay within hackathon-realistic time budgets — flag to the user if a request would meaningfully expand build scope rather than silently taking it on.

## Cross-Agent Context Sharing

### Cover the Gemini gap
Gemini reads `GEMINI.md`; Claude Code reads `CLAUDE.md`. Keep all three identical:
```bash
cp AGENTS.md CLAUDE.md
cp AGENTS.md GEMINI.md
```

### Dynamic context (session log)
Append a 2–4 line entry to `.agent-log/SESSION_LOG.md` when you finish a task (newest at top): what changed, why, and any gotcha the next agent should know. Read the top 2 entries before starting work. Archive entries to `.agent-log/archive/` once the log grows past ~10 entries so it stays cheap to read.
