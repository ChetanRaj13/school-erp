# School ERP — Hackathon Builds

Two parallel hackathon submissions sharing one architecture.

## Projects

1. **Smart School FinTech Innovation Challenge 2026** (organizer: PaperBuddy) — a standalone fee management system: dynamic fee engine, transaction/waiver/penalty tracking, omnichannel payments (UPI/card/netbanking + cash/cheque/DD reconciliation), and an animated glassmorphic admin dashboard.
2. **Future Ready Ops Innovation Challenge** — a unified school ERP that includes project 1's finance system as one module, plus AI document processing, timetable optimization, predictive resource allocation, and dual-mode (app + OMR) attendance.

Full architecture decisions, constraints, and hard rules live in **`AGENTS.md`** — read it before making changes. `CLAUDE.md` and `GEMINI.md` are kept identical to it for cross-agent consistency.

## Stack
- **Frontend**: Flutter + Riverpod — single codebase for mobile + web, role-based dashboards (Principal / Admin / Teacher / Student / Parent)
- **Backend/DB**: Supabase (PostgreSQL, Auth, Realtime, Row Level Security, Edge Functions) — one instance, domain-separated schemas (`finance`, `academic`, `staff`, `scheduling`, `attendance`, `documents`)
- **Payments**: Razorpay (Test Mode)
- **Timetable solver**: Google OR-Tools (CP-SAT), Python/FastAPI microservice
- **Document extraction**: Vision-LLM structured extraction
- **Attendance (OMR)**: OpenCV + ArUco markers for perspective correction

## Structure
```
AGENTS.md / CLAUDE.md / GEMINI.md   Shared agent rules — keep in sync (scripts/sync_agent_files.sh)
.agent-log/                          Session log for AI-agent context continuity
.env.example                         Copy to .env, fill in real keys, never commit .env

app/                                  Flutter app — single codebase, mobile + web
  lib/core/                           Supabase client, role-based router, theme
  lib/features/finance/               Fee engine, payments, reconciliation, payroll
  lib/features/admissions/            AI document capture + review UI
  lib/features/attendance/            App roll-call + OMR capture UI
  lib/features/timetable/             Timetable view + admin constraint input
  lib/features/predictive_alerts/     Proactive alert cards
  lib/features/dashboards/            One folder per role (principal/admin/teacher/student/parent)
  lib/shared/                         Reusable widgets + Riverpod providers

supabase/
  migrations/                         One SQL file per schema (finance/academic/staff/scheduling/attendance/documents)
  policies/                           RLS policies, one file per schema
  functions/                          Edge Functions (Razorpay webhook, doc-extraction trigger, realtime side-effects)
  seed/                               Local dev seed data

services/                             Python/FastAPI microservices
  timetable-solver/                   OR-Tools CP-SAT
  omr-pipeline/                       Already built & validated — generate_omr.py, scan_omr.py, test_pipeline.py
  document-extraction/                Vision-LLM structured extraction (not RAG)
  predictive-engine/                  Absence/substitute forecasting

docs/
  gap_analysis.md                     PaperBuddy audit findings (source of truth — don't invent new figures)
  architecture.md                     Longer-form architecture writeup
  pitch_decks/                        Round 1 PPTs go here

scripts/sync_agent_files.sh           Keeps AGENTS.md/CLAUDE.md/GEMINI.md identical
.github/workflows/ci.yml              Flutter analyze + Python service installs
```

## Status
See `.agent-log/SESSION_LOG.md` for the latest progress and any open gotchas.
