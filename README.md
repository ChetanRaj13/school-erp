# Post-Checkpoint Delivery — Setup Guide

This covers everything built since the message where I checked the 7 background image
dimensions ("Before I build anything — 7 images is an odd number..."). Nothing before
that point is included here — you'd already set those up. This zip + this README + the
Grok prompts at the bottom are the complete, ordered path to catch up.

---

## Part 1 — Files that need to be placed (this zip)

### Step 1: Extract

```powershell
cd "C:\Users\rajch\Desktop\AI\COMPS\school-erp-project-structure\school-erp"
Expand-Archive -Path "$HOME\Downloads\POST_ANCHOR_COMBINED.zip" -DestinationPath "." -Force
```

### Step 2: Register the background images in pubspec.yaml

Open app\pubspec.yaml, add under the flutter: section (near uses-material-design: true):

```yaml
  assets:
    - assets/backgrounds/
```

If an assets: entry already exists there from earlier tonight, just confirm
assets/backgrounds/ is listed — don't create a duplicate assets: key.

### Step 3: No new dependencies needed

Everything in this batch (file_picker, url_launcher, pdf, shared_preferences) uses
packages already added earlier in the session. Just run:

```powershell
cd app
flutter pub get
```

### Full file list, for reference

```
app/lib/core/theme/background_presets.dart          - 2 real presets
app/lib/core/theme/background_preset_provider.dart  - persisted selection
app/lib/shared/widgets/warm_backdrop.dart            - picks image by real screen width
app/lib/features/settings/settings_screen.dart       - preset picker with real thumbnails
app/assets/backgrounds/*.jpg                         - 4 real images

app/lib/features/dashboard/admin/offline_payment_screen.dart
app/lib/features/dashboard/admin/fee_management_screen.dart
app/lib/core/utils/receipt_generator.dart             - now includes GST tax invoice too

app/lib/features/dashboard/teacher/teacher_summary_screen.dart
app/lib/features/dashboard/teacher/teacher_attendance_screen.dart
app/lib/features/dashboard/teacher/gradebook_screen.dart
app/lib/features/dashboard/teacher/lesson_resources_screen.dart

app/lib/features/dashboard/student/student_overview_screen.dart
app/lib/features/dashboard/student/student_schedule_screen.dart
app/lib/features/dashboard/student/student_progress_screen.dart
app/lib/features/dashboard/student/student_library_screen.dart

app/lib/features/dashboard/parent/parent_overview_screen.dart
app/lib/features/dashboard/parent/parent_fees_screen.dart
app/lib/features/dashboard/parent/parent_schedule_screen.dart
app/lib/features/dashboard/parent/parent_notifications_screen.dart
```

---

## Part 2 — Database changes (already live, nothing for you to do)

Everything below was applied directly to your live Supabase database during this
session via direct SQL — not shipped as files, not something you need to run. Listed
here for transparency:

- Real bug fixed: academic.* and communications.* tables were missing table-level
  INSERT/UPDATE/DELETE grants (only had SELECT) - fixed
- Real privacy bug fixed: finance.waiver_requests had a broad "any authenticated user
  can read" policy exposing every family's waiver reasons to every parent - fixed and
  verified with a real simulated request
- New columns: finance.waiver_requests.disbursed_at, finance.payments.reference_number
- New RLS policies: finance.invoices INSERT, public.notifications INSERT,
  academic.grades UPDATE, finance.payment_plans parent-scoped INSERT (for EMI
  self-requests)
- New table + storage bucket from scratch: academic.lesson_resources +
  lesson-resources bucket, for Teacher's resource-sharing feature
- 1,200 real subject-wise marks generated across all 200 students x 6 subjects for
  Term 1, and another 1,200 for Term 2 with genuine per-student trends (37 students
  improved 10+ points, 34 declined 10+ points, rest roughly stable)

### Step 4: Verify the live data is really there

```powershell
npx supabase db query --linked "select term, count(*) from academic.grades group by term;"
```
Expect: Term 1 and Term 2, 1200 each.

---

## Part 3 - Honest, known gap (not fixed, not fakeable)

"Pay Online" is deliberately disabled in parent_fees_screen.dart, with an explanatory
tooltip. Only a Razorpay webhook (receives payment confirmation) has ever been
verified in this project - there's no confirmed order-creation endpoint the app can
call first. This needs real backend work before it can function - see Grok Prompt 5
below. I will not fake a "payment succeeded" flow client-side.

---

## Part 4 - Verification checklist once everything is placed

- [ ] flutter analyze - should be clean
- [ ] Settings screen (once Grok wires it in) shows 2 real background thumbnails
- [ ] Resize the browser window - background should swap around 800px width
- [ ] Every new screen at least opens without a red error screen

---

# Part 5 - Grok prompts, in order

Send these ONE AT A TIME, in this exact order. All were written but never sent.

## Prompt 1 - Cross-cutting bug fix (do this FIRST)

```
Fix a real, systemic Dart bug found across probably 10+ screens tonight:
setState(() => _future = _load()). In Dart, this is an assignment EXPRESSION that
evaluates to the assigned value, so the arrow function actually returns a Future,
which Flutter's setState explicitly rejects at runtime with "setState() callback
argument returned a Future".

Grep the whole app/lib directory for this exact pattern and fix every occurrence by
converting to a block body:

  WRONG:  setState(() => _future = _load());
  RIGHT:  setState(() { _future = _load(); });

Also fix a related, more serious bug in teacher_assignments_screen.dart's grading
dialog: the Save button calls Navigator.pop() TWICE in a row, synchronously, with no
async work between them - popping the dialog and the submissions sheet blind. This
causes a real "screen goes blank" bug (confirmed via user testing) because the second
pop can over-pop past the intended target. Restructure so the async grade-save happens
FIRST, then pop only the dialog, then let the parent screen refresh normally.

Run flutter analyze when done, then verify with real clicks on at least 5-6 of the
affected screens across different roles - this is a runtime bug, static analysis alone
won't catch it.
```

## Prompt 2 - Wire in every new screen from this delivery

```
Read every file's CURRENT content before editing - this touches nav_config.dart and
app_router.dart across every role.

New screens to wire in:

Settings (all roles, near sign-out):
- app/lib/features/settings/settings_screen.dart

Admin (Finance section):
- app/lib/features/dashboard/admin/offline_payment_screen.dart
- app/lib/features/dashboard/admin/fee_management_screen.dart

Teacher - make teacher_summary_screen.dart the new LANDING page:
- app/lib/features/dashboard/teacher/teacher_summary_screen.dart
- app/lib/features/dashboard/teacher/teacher_attendance_screen.dart
- app/lib/features/dashboard/teacher/gradebook_screen.dart
- app/lib/features/dashboard/teacher/lesson_resources_screen.dart

Student - make student_overview_screen.dart the new LANDING page:
- app/lib/features/dashboard/student/student_overview_screen.dart
- app/lib/features/dashboard/student/student_schedule_screen.dart
- app/lib/features/dashboard/student/student_progress_screen.dart
- app/lib/features/dashboard/student/student_library_screen.dart

Parent - make parent_overview_screen.dart the new LANDING page:
- app/lib/features/dashboard/parent/parent_overview_screen.dart
- app/lib/features/dashboard/parent/parent_fees_screen.dart
- app/lib/features/dashboard/parent/parent_schedule_screen.dart
- app/lib/features/dashboard/parent/parent_notifications_screen.dart
Also add Announcements and Messages routes for Parent - they don't exist yet.

Verify every new route with a real click after wiring, not just flutter analyze.
```

## Prompt 3 - Admin: HR/Finance workspace split + new Overviews

```
Build a workspace split for Admin - ONE login role, TWO UI workspaces. A toggle at
the top of Admin's sidebar (HR / Finance) changes which sections show below it, plus
a shared "Operations" section always visible (Announcements, Messages, OMR
Attendance, Document Review, Weekly Timetable).

HR workspace: Payroll, HR Approvals (payroll only, filtered from the existing
Approval Queue, don't duplicate the screen), Leave Requests.

Finance workspace: Vendors & Procurement, Finance Approvals (POs + vendor payments
only, same Approval Queue different filter), EMI/Financing, Late Fees, Scholarships
& Waivers, Budget, Bank Reconciliation, Fee Management, Offline Payment Entry, Recent
Payments (moved out of Overview into its own section here).

Two new Overviews, real data only:

HR Overview: staff headcount by role, leave request summary, payroll summary. HONEST
GAP: public.staff_attendance has zero rows anywhere - show "not yet in use," never a
fabricated percentage.

Finance Overview: fee collection (collected/pending/overdue), revenue vs expense vs
budget, purchase-order pipeline by status, EMI plans active, pending waivers count.

Also:
1. Waiver disbursement: waiver_requests_screen.dart needs a "Disburse" action on
   approved-but-not-yet-disbursed requests - reduce invoice.amount_due by
   requested_amount, set disbursed_at = now(). Only show when status='approved' AND
   disbursed_at IS NULL.
2. GST invoice generation (ReceiptGenerator.generateGstInvoiceAndUpload, already
   built) needs a real trigger point in Fee Management or an invoice detail view.

Verify with real clicks.
```

## Prompt 4 - Teacher: targeting fixes

```
Two fixes for Teacher, once new screens are wired in:

1. Add class_id targeting to Announcements - a teacher should be able to pick "just
   my class" instead of always school-wide. Column already exists, unused so far.

2. Filter Messages' compose recipient list, for teachers specifically, to students in
   classes they actually teach (via scheduling.timetable), not the full school.
```

## Prompt 5 - Parent: message restriction + the real Razorpay gap

```
Three items for Parent:

1. Restrict Parent's Messages compose list to ONLY: the class teacher of their linked
   child(ren), Principal, and Admin - not the full staff list.

2. REAL BACKEND VERIFICATION NEEDED - check supabase/functions/ directly for whether
   a Razorpay ORDER-CREATION endpoint exists, separate from the existing payment
   webhook. If it doesn't exist, this needs to be built before "Pay Online" (currently
   deliberately disabled) can work: a Supabase Edge Function creating a real Razorpay
   order, returning order_id, then the app needs razorpay_flutter wired to open
   checkout with that real order. The existing webhook must remain the actual source
   of truth for marking an invoice paid - never trust a client-side success callback.

3. EMI/Financing screen (admin-facing) needs to show payment_plans with
   status='requested' as a distinct "Parent Requests" section with Approve/Reject -
   parallel to waiver approval. This is what makes Parent's "Request EMI" go anywhere.

Report real, verified results.
```
