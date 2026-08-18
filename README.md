# School ERP — Future-Ready Ops

**Submission for [PaperBuddy EduHack](https://paperbuddy.in/hacktheweb#/future-ready-ops) — Future-Ready Ops track.**

Five roles — Principal, Admin, Teacher, Student, Parent — sign into one connected system that replaces the manual data entry, physical document storage, and siloed scheduling the track brief describes, backed by a Postgres database (Supabase) with row-level security enforcing who can see and touch what.

## The challenge, and how this answers it

> "School administration remains heavily reliant on manual data entry, physical document storage, and siloed scheduling systems, leading to extreme inefficiencies. Build intelligent, AI-powered solutions that automate everyday school operations, digitize records, and drastically reduce the administrative workload."

That's the brief. Here's what's actually built against each part of it — not a pitch, a map from the track's own requirements to real, running code.

### Core Technical Requirements

**AI Document Processing** — a Supabase Edge Function (`document-extraction-trigger`) takes a photographed or scanned admission form, calls a vision-capable LLM, and returns structured fields for review before they're committed to the database by a second function (`document-commit`). A parent's paper form becomes a reviewable draft record, not a re-typing job for office staff.

**Timetable Optimization** — the timetable isn't hand-built or greedily assigned; `services/timetable-solver` formulates it as a real constraint-satisfaction problem and solves it with **Google OR-Tools' CP-SAT solver** — hard constraints (no class or teacher double-booked, exact periods-per-week per subject, qualified-teacher-only assignment) with room assignment and infeasibility reporting when a valid schedule genuinely doesn't exist, rather than silently producing a broken one.

**School ERP Automation** — every financial, academic, and administrative table lives in one Postgres schema instead of scattered legacy apps, and the UI stays synced across roles the way the brief specifically asks: the whole app is built on **Riverpod** (`flutter_riverpod`) for reactive state, with a shared `RoleShell` (a `go_router` `StatefulShellRoute`) providing one consistent navigation chrome that ~30 screens plug into rather than each role reinventing its own shell.

### The Admin Dashboard

The brief asks for "a centralized command center designed for minimal clicks... proactive alerts for operational bottlenecks rather than hunting for data." `admin_dashboard.dart` already has a live `SystemAlertsWidget` surfacing pending approvals and operational alerts up front, plus dedicated HR and Finance overview screens (staff headcount, leave summary, payroll status, fee collection vs. pending vs. overdue, purchase-order pipeline) — the numbers are pulled from real invoice/payment/staff data, not static placeholders.

### Think outside the box

**Predictive resource allocation** — this exists in two real, honestly-distinct pieces, not one:
- **Live today**: `principal_dashboard.dart` and `teacher_summary_screen.dart` both call an `analytics.get_at_risk_students` database function and render an "At-Risk Students Monitor" — predictive student-welfare flagging from historical attendance and grade trends, already on screen.
- **Built, not yet wired to a UI**: `services/predictive-engine/predictor.py` goes further — a hybrid heuristic + actual **scikit-learn logistic regression model** (`compute_absence_risk_hybrid`) trained on historical attendance patterns, plus a `find_resource_gaps` function aimed at exactly the staff-assignment allocation problem the brief describes. It's real, tested logic sitting behind a FastAPI service — the remaining work is a dashboard screen to surface it, not the prediction itself.

**Automated attendance** — not RFID, but the same "computer vision seamlessly into the ERP" idea: `services/omr-pipeline` uses OpenCV with **ArUco marker detection** to correct a photographed attendance sheet's perspective, then reads bubble-fill fractions to mark attendance — a phone photo of a paper sheet becomes structured attendance data without manual entry.

## How this maps to the evaluation criteria

**Innovation & Impact** — the fintech layer (Razorpay online payments with server-verified webhook confirmation, EMI financing, waiver approval workflows, payroll, vendor procurement) goes beyond what the track brief asks for on its own, tackling a second real administrative pain point — money — alongside documents, timetables, and attendance. `docs/gap_analysis.md` is a direct audit of PaperBuddy's own public demo, used to make sure this project's feature set doesn't just duplicate what already exists.

**Technical Execution** — Postgres row-level security scoping every table by school and role; a signature-verified, idempotent Razorpay webhook with atomic balance updates (no race conditions on money); OR-Tools CP-SAT for the timetable; a real ArUco/OpenCV computer-vision pipeline for OMR; Riverpod + go_router throughout the Flutter app. See `SECURITY.md` for the honest current security posture, including what's still open, not just what's fixed.

**UI/UX Design** — the app is mid-migration to a flatter, higher-contrast, purpose-built design system (`docs/design.md`) — bold color-blocking, pill shapes, no drop shadows — replacing an earlier photo-backdrop theme, with role-based accent colors for wayfinding across the five dashboards.

## Stack

- **App**: Flutter (web), Riverpod for state, go_router for navigation
- **Backend**: Supabase — Postgres, auth, storage, Edge Functions (Deno/TypeScript), row-level security scoping every table by school and role
- **Payments**: Razorpay, via a server-verified Edge Function + webhook flow
- **Microservices** (FastAPI, via Docker Compose): OMR attendance (OpenCV/ArUco), timetable solver (OR-Tools CP-SAT), predictive engine (scikit-learn)

## Project layout

```
app/                  Flutter application (all 5 role dashboards live under lib/features/dashboard/)
supabase/              Migrations, Edge Functions (Razorpay order + webhook, document extraction, attendance sync), config
services/              FastAPI microservices (OMR pipeline, timetable solver, predictive engine)
docs/                  Living project documentation — design system, architecture, tech debt, PaperBuddy gap analysis
scripts/               Utility scripts
test/                  Tests
docker-compose.yml     Runs the microservices locally
SECURITY.md            Security posture — what's fixed, what's known-open
CONTRIBUTING.md        Real lessons from this project's history (multi-agent workflow, migration numbering, Postgres gotchas)
```

## Running it locally

```bash
# Flutter app
cd app
flutter pub get
flutter run -d chrome

# Backend microservices
docker compose up -d
```

### One-command local dev (Windows / PowerShell)

```powershell
.\start-dev.ps1
```

You'll need a `.env` file (see `.env.example`) with your Supabase project URL, anon key, and Razorpay test keys — not committed.

## Where things actually stand

**Working**: fee tracking, offline and online payment (Razorpay, webhook-confirmed), payroll, HR/Finance approval queue, vendor/procurement, waiver and EMI approval flow, financial dashboards, admission intake with AI document extraction, OMR computer-vision attendance, the OR-Tools timetable solver, and live at-risk-student prediction on two dashboards.

**Known gaps**: the predictive engine's staff-resource-gap model is built and tested but not yet surfaced in any screen; a handful of legacy unrouted dashboard screens are flagged for cleanup, not deletion, in `docs/tech_debt.md`. See `SECURITY.md` for the current security posture, including what's still open.

## Demo accounts

| Role | Email | Password |
|---|---|---|
| Principal | `ravi@gmail.com` | abcd@1234 |
| Admin | `anita@gmail.com` | abcd@1234 |
| Teacher | `cdsingh@gmail.com` | abcd@1234 |
| Student | `chintu@gmail.com` | abcd@1234 |
| Parent | `papa@gmail.com` | abcd@1234 |

> These are real accounts on a live Supabase project with real data behind them. If this repo is public, reset these passwords to values you're comfortable putting in a public file, or move this table somewhere `.gitignore`d.
