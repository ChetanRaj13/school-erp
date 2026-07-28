# School ERP — Fintech Suite

A submission for the **Smart School Fintech Innovation Challenge**. This project reimagines how a school handles money — fee collection, payments, payroll, procurement, and financial oversight — as a single connected system instead of registers, spreadsheets, and manual reconciliation.

Five roles sign into one app — Principal, Admin, Teacher, Student, Parent — and each sees a role-specific view of the same underlying financial data, backed by a Postgres database with row-level security enforcing who can see and touch what.

## The core fintech problem this solves

Schools handle a surprising amount of financial complexity: fee collection across hundreds of students with different due dates and partial payments, late fee calculation, scholarship and waiver approvals, EMI-style fee financing for families who can't pay in one lump sum, vendor payments, payroll, and reconciliation — most of it still done by hand in a lot of schools. This project puts all of it on rails: every rupee is tracked from invoice to payment to reconciliation, with an audit trail and approval workflow instead of a paper register.

## Razorpay — online fee payments

Online payment is the centerpiece of the fintech story here: a parent should be able to open the app, see exactly what's due for their child, and pay it — with the money landing correctly against the right invoice, no manual entry required on the school's side.

How it's wired:

- **Order creation** happens server-side through a Supabase Edge Function — the app never talks to Razorpay directly with a client-trusted amount. The order amount is meant to be looked up from the actual invoice on the server, not passed in blind from the client, so a parent can't tamper with what they're charged.
- **Checkout** opens via `razorpay_flutter` on mobile, with a web-specific bridge for Flutter web (Razorpay's SDK is JS-based, so the web build talks to it through a small interop layer rather than the native package).
- **Payment confirmation is webhook-driven, not client-driven** — a Razorpay webhook is the only thing allowed to mark an invoice as paid. The webhook verifies the payment signature (constant-time HMAC-SHA256) before touching the database, so a spoofed "success" callback from the client can never fake a payment.
- **Idempotency** — duplicate webhook deliveries for the same payment are detected and ignored, so a network retry from Razorpay can't double-count a payment.
- **Atomic balance updates** — when a payment lands, the invoice's paid amount is updated with a single atomic Postgres operation, not a read-then-write from the app, so two payments arriving close together can't silently overwrite each other and lose money.
- **Test mode** — currently running against Razorpay's test environment, so the full payment flow can be demoed end-to-end without moving real money.

## Other fintech features

- **Fee management** — per-student invoices, partial payments, offline payment recording (cash/cheque) with the same atomic balance-update guarantee as online payments, and GST-compliant invoice generation
- **Late fees** — automatic calculation on overdue invoices
- **Scholarships & waivers** — parents can request a fee waiver; admin approves or rejects, and approved waivers reduce the invoice balance with a clear disbursement step and timestamp
- **EMI / fee financing** — parents can request to split a fee into installments instead of paying in full, with an admin approval step before a payment plan becomes active
- **Payroll** — staff salary runs, with an approval queue before payments are finalized
- **Vendor & procurement** — purchase orders, vendor performance tracking, and vendor payments, each going through the same approval-queue pattern as payroll
- **Bank reconciliation** — matching recorded payments against what's actually settled
- **Financial oversight dashboards** — fee collection vs. pending vs. overdue, revenue vs. expense vs. budget, purchase-order pipeline by status, all built from real invoice and payment data rather than static numbers

## Roles and what each one does financially

- **Principal / Admin** — full financial oversight: fee management, payroll, vendor payments, budget, approvals for both HR and Finance workflows
- **Parent** — sees exactly what's owed for their child, pays online via Razorpay or waits on an approved waiver/EMI plan
- **Student** — read-only visibility into their own fee status
- **Teacher** — no direct financial role, kept separate from money-handling by design

## Stack

- **App**: Flutter (web), Riverpod for state, go_router for navigation
- **Backend**: Supabase — Postgres, auth, storage, Edge Functions (Deno/TypeScript), row-level security scoping every financial table by school and role
- **Payments**: Razorpay, via a server-verified Edge Function + webhook flow
- **Microservices**: FastAPI, for supporting features like document extraction and OMR-based attendance, run via Docker Compose

## Project layout

```
app/            Flutter application (all 5 role dashboards live under lib/features/dashboard/)
supabase/       Migrations, Edge Functions (including the Razorpay order + webhook functions), config
services/       FastAPI microservices
docs/           Project documentation
scripts/        Utility scripts
test/           Tests
docker-compose.yml   Runs the microservices locally
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

You'll need a `.env` file (see `.env.example`) with your Supabase project URL, anon key, and Razorpay test keys. These aren't committed — ask whoever's holding the project credentials.

Database migrations are applied directly to the shared Supabase project; there's no local migration step required to run the app against it.

## Security, as it relates to handling money

- Row-level security on every financial table, scoped by school and role — a parent can only ever see their own child's invoices, an admin only their own school's data
- Payment confirmation trusted only from the signature-verified Razorpay webhook, never from the client
- Atomic balance updates on every payment path (online and offline) to eliminate race conditions on invoice balances
- Approval workflows (not single-click actions) on payroll, vendor payments, waivers, and EMI requests, so no financial commitment happens without a second set of eyes

## Where things actually stand

**Working**: fee tracking, offline payment recording, payroll, the HR/Finance approval queue, vendor/procurement flow, waiver and EMI request-and-approval flow, financial dashboards, and the full Razorpay webhook-confirmation path.

**Known gap**: the client-side "Pay Online" checkout trigger is still being finished — the webhook confirmation side (the half that actually matters for trusting a payment happened) is built and verified; the order-creation call from the app is the remaining piece.

## Demo accounts

One test account exists per role, so you can log in and click through as any of them:

| Role | Email | Password |
|---|---|---|
| Principal | `ravi@gmail.com` | *(fill in)* |
| Admin | `anita@gmail.com` | *(fill in)* |
| Teacher | `cdsingh@gmail.com` | *(fill in)* |
| Student | `chintu@gmail.com` | *(fill in)* |
| Parent | `papa@gmail.com` | *(fill in)* |

> **Before publishing this section**: these are real accounts on a live Supabase project with real data behind them. If this repo is public, anyone with these credentials can log in and interact with the actual database — not a sandbox copy. Either keep this repo private, move this table to a `.gitignore`d file and share it separately, or reset these passwords to values you're comfortable putting in a public file.
