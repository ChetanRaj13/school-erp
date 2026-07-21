# Architecture Overview

See AGENTS.md for the authoritative, enforced version of these decisions.
This file is the longer-form explanation for pitch decks / documentation.

## Layers
1. Presentation — Flutter + Riverpod, single codebase (mobile + web), role-based dashboards
2. API / Edge Functions — Supabase Edge Functions (Deno) for webhooks + service triggers
3. Core services — Supabase Postgres (finance/academic/staff/scheduling/attendance/documents schemas)
4. External microservices — Python/FastAPI: timetable-solver (OR-Tools), document-extraction (Vision-LLM), predictive-engine, omr-pipeline
5. Integrations — Razorpay (Test Mode), Vision-LLM API, WhatsApp/SMS (future scope)
6. Security — Row Level Security per table, DPDP Act–aligned consent handling

## Data flow (fee payment example)
Parent app -> Razorpay checkout -> Razorpay webhook -> Supabase Edge Function
-> finance.transactions insert -> Realtime push -> Admin dashboard updates live
