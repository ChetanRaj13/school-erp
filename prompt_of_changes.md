# School ERP – Agent Prompt File

---

## How to Use This File

This file contains numbered prompts for an AI coding agent (Grok or equivalent).

**Follow these rules exactly:**

1. **One prompt at a time.** Execute prompts sequentially. Do not attempt multiple prompts in parallel.
2. **Complete each prompt fully** before moving to the next. A prompt is complete only when all implementation is done, the app compiles, and the feature works end-to-end.
3. **After completing each prompt**, append a structured log entry to:
   `C:\Users\rajch\Desktop\AI\COMPS\school-erp-project-structure\school-erp\.agent-log\SESSION_LOG.md`
   The log entry must include:
   - Prompt number completed
   - Files modified (with paths)
   - Database migrations created (if any)
   - Features implemented
   - Bugs fixed
   - Any blockers or remaining issues
4. **After logging**, run `/clear` and start a new chat. In the new chat, instruct the agent to:
   - Read this prompt file (`prompt_of_changes.md`)
   - Read the session log (`SESSION_LOG.md`) to understand what has already been done
   - Continue from the next unfinished prompt
5. **Block order:** Complete all prompts in Block 1 first, then proceed to Block 2.
6. **Do not skip prompts.** If a prompt cannot be completed due to a genuine technical blocker, log the blocker clearly and proceed to the next prompt.

---

## SESSION LOG ENTRY FORMAT

Append this structure after each completed prompt:

```
## Prompt [N] — [Short Title]
Date: YYYY-MM-DD
Status: COMPLETE / PARTIAL / BLOCKED

### Files Modified
- path/to/file.dart
- path/to/migration.sql

### Database Migrations
- migration_name.sql — description of what it does

### Features Implemented
- Brief description

### Bugs Fixed
- Brief description

### Blockers / Remaining Issues
- None / description
---
```

---

## Project Context

- **Stack:** Flutter (web + mobile) + Supabase (PostgreSQL, RLS, Edge Functions)
- **Project ID:** `yhcyhwpdgqupylrnkqht` (ap-south-1), project name: `smart-school-fintech`
- **App entry:** `app/lib/main.dart`
- **Run command:** `flutter run -d chrome --dart-define-from-file=dart_define.json --web-port=8084`
- **Design language:** Existing components (`GlassCard`, `WarmBackdrop`, `AppColors`, `AppRadii`) — reuse everywhere, do not introduce new design patterns
- **Architecture:** Riverpod state management, `go_router` navigation, Supabase client via `supabaseClientProvider`
- **Schema:** Primary tables live in the `finance` schema; auth/user tables in `public`

### General Implementation Rules

- Implement fully — do not stop at analysis or recommendations
- Reuse existing components and architecture wherever possible
- Do not break existing functionality
- Create Supabase migrations for every schema change — never mutate the DB directly
- If a feature spans multiple modules, update all affected files
- Only stop if there is a genuine technical blocker (and log it)

---

# BLOCK 1

> **Prerequisites for Block 1:** The Principal Dashboard and Budget Module must already exist in the codebase. Block 1 builds on top of those. Read `SESSION_LOG.md` before starting to confirm what has been implemented in prior sessions.

---

## Prompt 6 — Budget Module: Advanced Features

**Context:** The Budget Dashboard redesign (KPI cards, charts, department cards) was completed in a prior session. This prompt adds deeper functionality on top of that foundation.

**Objective:** Extend the Budget Module with the following features. If backend support is missing for any feature, implement it cleanly using the existing Supabase + Edge Function architecture.

### Features to Implement

**History & Revisions**
- Budget History: view past budget states by fiscal year
- Budget Revisions: log and display changes made to a budget (who changed what, when, old value vs new value)
- Financial Audit Trail: every budget create/update/delete must be logged with user, timestamp, and before/after values

**Analysis & Comparison**
- Variance Analysis: budgeted vs actual spending, with variance amount and percentage per department
- Department Comparison: side-by-side comparison of department budget utilization
- Multi-year Comparison: compare budget vs actual across multiple fiscal years on a single chart

**Views & Navigation**
- Fiscal Year Selector: switch between fiscal years; all charts and cards update accordingly
- Monthly / Quarterly / Yearly View toggle: affects all trend charts
- Forecasting: project end-of-year spending based on current burn rate

**Reporting & Export**
- Budget Notes: free-text notes per department per fiscal year, stored in DB
- Export to PDF: printable budget report (current view)
- Export to Excel: structured spreadsheet of budget data
- Printable Reports: print-friendly layout

### Deliverables
- Files Modified
- Database Migrations (if any)
- Features Implemented
- Bugs Fixed
- Remaining Issues (if any)

---

## Prompt 7 — Principal Dashboard: Final Review & Polish

**Context:** The Principal Dashboard was built and cleaned up in prior sessions. This prompt is a comprehensive QA pass over the entire Principal Dashboard.

**Objective:** Review every aspect of the Principal Dashboard and fix all issues found. Do not introduce unnecessary refactoring.

### Review Checklist

**UI & UX**
- [ ] Consistent use of design language (`GlassCard`, `AppColors`, typography, spacing)
- [ ] All screens are responsive across web breakpoints
- [ ] Loading states on every async screen
- [ ] Empty states on every list/table
- [ ] Error handling with user-visible messages on every async call

**Navigation**
- [ ] All navigation links work correctly
- [ ] No dead or broken routes
- [ ] Role permissions enforced — Principal cannot access Admin-only screens
- [ ] Back navigation works on all screens

**Data & Performance**
- [ ] No N+1 queries
- [ ] Pagination or lazy loading on all large lists
- [ ] No unnecessary rebuilds

**Features**
- [ ] Charts render correctly with real data and handle empty data gracefully
- [ ] Tables support search, filter, and sort where appropriate
- [ ] Notifications work end-to-end
- [ ] All role-specific features are present and functional

**Code Quality**
- [ ] No dead code
- [ ] No duplicate widgets or logic
- [ ] No hardcoded strings that should be constants

### Deliverables
- Files Changed
- Bugs Fixed
- UX Improvements
- Performance Improvements
- Remaining Recommendations

> This concludes Block 1. After logging Prompt 7, proceed to Block 2.

---

# BLOCK 2

> **Prerequisites for Block 2:** Block 1 must be fully complete and logged before starting Block 2. Read `SESSION_LOG.md` to confirm.

---

## Prompt 1 — Principal Dashboard Cleanup

**Objective:** Ensure the Principal Dashboard contains only features appropriate for the Principal role.

### Tasks
- Remove Offline Payment Entry from the Principal Dashboard (it belongs to Admin/Finance only)
- Review all Principal screens and navigation items
- Remove any feature that does not belong to the Principal role
- Fix any broken navigation links
- Fix role permission guards if any Principal screen incorrectly allows or blocks access
- Remove dead navigation entries

### Deliverables
- Files Modified
- Features Removed (with justification)
- Bugs Fixed
- Remaining Issues (if any)

---

## Prompt 2 — Admin Dashboard Redesign

**Objective:** Replace the current Admin Dashboard (which only shows recent payments) with a proper executive ERP dashboard that immediately communicates the school's financial and operational health.

Maintain the existing design language throughout.

### KPI Cards
- Total Students
- Total Staff
- Active Teachers
- Monthly Revenue
- Outstanding Fees
- Monthly Collections
- Total Expenses
- Budget Utilization %
- Pending Approvals
- Attendance Percentage
- Active Vendors

### Charts
- Fee Collection Trend (line, last 12 months)
- Revenue vs Expenses (bar, monthly)
- Monthly Cash Flow (area)
- Budget Utilization (donut/gauge)
- Student Admission Trend (line)
- Expense by Category (pie)
- Payment Method Distribution (pie/donut)
- Vendor Spending (bar)

### Dashboard Widgets
- Recent Activities feed
- Pending Tasks list
- Approval Queue Summary (count by type)
- Upcoming Fee Deadlines (next 7 days)
- Recent Announcements
- System Alerts (failed payments, overdue fees, budget overruns)
- Top Fee Defaulters (top 5 by outstanding amount)
- Quick Actions (shortcuts to common admin tasks)

### Deliverables
- Files Modified
- Database Changes (if any)
- Features Implemented
- Remaining Issues (if any)

---

## Prompt 3 — Search, Filter & Sorting System

**Objective:** Create a reusable search, filter, and sorting system and apply it to all modules with large datasets.

### Reusable Components to Build
- `SearchBar` widget (searches by student name or admission number)
- `SortControl` widget (dropdown: Name / Admission Number / Date / Amount / Status)
- `FilterPanel` widget (configurable per module)
- Pagination widget or infinite scroll wrapper

### Modules to Update
Apply search + sort + filter + pagination to:
- Fee Management
- Approval Queue
- EMI / Fee Financing
- Vendor Performance
- Scholarships & Waivers
- Offline Payments
- Any other screen containing a large list or table

### Filter Contexts (examples — adapt to what makes sense per module)
- Fee Management: by class, section, fee status, due date range
- Approval Queue: by type, status, date range
- EMI: by status (requested / approved / rejected / active), student
- Vendor: by category, spend range, performance rating
- Scholarships: by status, type, disbursement date

### Deliverables
- Components Created
- Modules Updated
- Files Modified
- Remaining Issues (if any)

---

## Prompt 4 — Finance Overview Fix

**Objective:** Fix the Finance Overview screen which currently crashes with a database error because it references `invoices.status`, a column that does not exist.

### Tasks
- Inspect the Finance Overview screen code and identify all queries referencing `invoices.status`
- Inspect the `finance.invoices` table schema to determine what columns actually exist
- Fix the query to use the correct column(s)
- If a status column is genuinely needed and missing, create a migration to add it with appropriate values and constraints
- Verify Finance Overview loads without errors
- Remove any other broken DB references found during review

### Deliverables
- Root Cause
- Files Modified
- Database Migration (if created)
- Verification: Finance Overview loads successfully

---

## Prompt 5 — Offline Payment Entry Redesign

**Objective:** Replace the current minimal Offline Payment Entry with a professional accounting-style payment entry system.

### Student Lookup
- Search by Admission Number or Student Name (autocomplete)
- On selection, auto-populate:
  - Student Name, Roll Number, Class, Section
  - Parent Name
  - Outstanding Fees (total and per fee head)
  - Due Dates
  - Fee Structure breakdown
  - Previous Payment Summary (last 3 payments)

### Payment Details Form
- Payment Date (defaults to today)
- Payment Method (Cash / Cheque / Bank Transfer / UPI / DD)
- Amount Received
- Remaining Balance (calculated live)
- Reference / Cheque Number (required for non-cash methods)
- Remarks
- Received By (defaults to logged-in user)
- Auto-generated Receipt Number (format: RCP-YYYYMM-XXXX)

### Fee Allocation
- Display all pending fee components with amounts due
- Allow: pay individual fee heads, pay multiple fee heads, or pay entire outstanding balance
- Auto-allocate payment across fee heads (oldest due first, or by fee head priority)
- Show real-time allocation preview

### Live Summary Panel
- Total Due
- Amount Entered
- Remaining Balance (or overpayment warning if amount exceeds due)
- Receipt Preview (compact)
- Updates in real time as the user types

### Actions
- Save Payment (writes to `finance.payments`, updates `finance.invoices`)
- Generate Receipt (PDF)
- Print Receipt
- Send Receipt to Parent (uses existing notification infrastructure)
- Cancel (with unsaved-changes confirmation)

### Deliverables
- Files Modified
- Database Changes (if any)
- Features Implemented
- Remaining Issues (if any)

---

## Prompt 6 — Budget Dashboard Redesign

**Objective:** Replace the current Budget page with a proper executive financial dashboard.

### KPI Cards
- Annual Budget
- Budget Utilized (amount + %)
- Remaining Budget
- Payroll (current month)
- Operating Expenses (current month)
- Monthly Burn Rate
- Forecast Spending (projected end-of-year)
- Emergency Reserve

### Charts
- Budget vs Actual (bar, by department)
- Department-wise Spending (horizontal bar)
- Monthly Spending Trend (line)
- Expense Categories (pie/donut)
- Historical Budget Comparison (multi-year bar)
- Forecast Analysis (line with projection)

### Department Cards
Each department card shows:
- Department Name
- Allocated Budget
- Amount Used
- Remaining Budget
- Utilization % (with progress bar)
- Budget Health Indicator (Green / Amber / Red based on utilization thresholds)

### Additional Sections
- Budget Health Summary (overall school financial health score)
- Financial Alerts (departments over 90% utilization, overruns)
- Quick Actions (Add Budget, Request Revision, Export Report)
- Drill-down: clicking a department opens detailed breakdown

### Deliverables
- Files Modified
- Database Changes (if any)
- Features Implemented
- Remaining Issues (if any)

---

## Prompt 7 — Scholarships & Waivers: Proper Fee Integration

**Objective:** Fix the Scholarships & Waivers module so disbursement correctly reduces outstanding fees and cannot be applied when fees are already paid.

### Correct Disbursement Behaviour
When a scholarship is disbursed:
1. Verify student exists and scholarship is in `approved` status
2. Check outstanding balance > 0; if fees are fully paid, disable Disburse button and show "Fees Already Paid" — do not create any transaction
3. If scholarship amount > outstanding balance: either cap it to the remaining balance or block disbursement with a clear message — do not create negative balances
4. On valid disbursement:
   - Reduce `finance.invoices.amount_paid` (or equivalent) by the scholarship amount
   - Create a record in `finance.payments` (method: `scholarship`, status: `success`)
   - Update scholarship status to `disbursed`
   - Trigger a notification to the parent

### Audit Trail
Every disbursement must log:
- Scholarship ID
- Linked Invoice ID
- Amount disbursed
- Performed by (user ID)
- Timestamp
- Status before and after

### Parent Dashboard Reflection
- Outstanding balance updates immediately after disbursement
- Scholarship disbursement appears in payment history
- Financial reports include scholarship disbursements

### Deliverables
- Root Cause Analysis (where was the money going before?)
- Files Modified
- Database Migration (audit trail table if needed)
- Features Implemented
- Bugs Fixed

---

## Prompt 8 — Late Fee Notifications

**Objective:** Automatically notify all affected parents whenever a Late Fee Rule is created, updated, or deleted.

### Trigger Points
- Late Fee Rule created → notify parents of affected fee structures
- Late Fee Rule updated → notify parents with old value, new value, and effective date
- Late Fee Rule deleted → notify parents that the rule has been removed

### Notification Content
Each notification must include:
- What changed (created / updated / deleted)
- Old Value (for updates/deletes)
- New Value (for creates/updates)
- Effective Date
- Deep link to Fee Details screen

### Implementation
- Reuse the existing notification infrastructure (do not build a new system)
- Notifications should be triggered server-side (Edge Function or DB trigger) to ensure they fire regardless of which admin performs the action
- Respect existing notification delivery channels (in-app, push, or whatever is already implemented)

### Deliverables
- Files Modified
- Edge Function / DB trigger created
- Notifications working end-to-end
- Remaining Issues (if any)

---

## Prompt 9 — Final QA & Polish

**Objective:** Perform a comprehensive quality pass across the entire application and fix all issues found. Do not introduce unnecessary refactoring.

### Review Areas

**UI Consistency**
- All screens use the same design language (GlassCard, AppColors, typography, spacing)
- No screen has hardcoded colours or font sizes outside the theme

**Navigation**
- All routes work correctly for all roles
- No broken or dead links
- Role permissions enforced everywhere

**Responsiveness**
- All screens usable on web (1280px+), tablet (768px), and mobile (375px)

**Database**
- No queries referencing non-existent columns
- All RLS policies correct for all roles
- No missing indexes on frequently queried columns

**Performance**
- No N+1 queries
- Pagination or lazy loading on all large lists
- No unnecessary widget rebuilds

**Accessibility**
- All interactive elements have semantic labels
- Colour contrast meets WCAG AA

**States**
- Loading states on every async operation
- Empty states on every list/table
- Error states with retry options on every async screen

**Code Quality**
- No dead code
- No duplicate widgets or business logic
- No unused imports or variables

### Final Deliverables
Provide a structured report:
- Features Implemented (Block 1 + Block 2 summary)
- Files Modified (complete list)
- Database Migrations (complete list)
- Bugs Fixed
- UI Improvements
- Performance Improvements
- Remaining Recommendations
