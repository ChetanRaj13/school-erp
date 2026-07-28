# School ERP — Context Handoff Brief
**Project:** Coal-Coders / Chetan Raj — School ERP hackathon build
**Supabase project:** `yhcyhwpdgqupylrnkqht` ("smart-school-fintech", ap-south-1)
**Last updated:** 2026-07-28, by Antigravity (configured Vercel build settings for Flutter Web)

> **How to use this file:** Any AI working on this project (Claude, Grok, Claude Code, etc.)
> should read this file plus `AGENTS.md` and the top 2 entries of `.agent-log/SESSION_LOG.md`
> before starting work. This file is the durable cross-session memory; `SESSION_LOG.md` is the
> append-only chronological log. See **"Multi-agent handoff protocol"** at the bottom for how
> to keep both in sync going forward.

---

## 1. Current state (as of 2026-07-27)

### ✅ Resolved this session (via direct Supabase DB access, live-verified)

| Item | What happened |
|---|---|
| RLS gap on 7 tables | `academic.grades/submissions/class_roster/assignments/subjects/lesson_resources` + `communications.messages` were readable by any authenticated user regardless of role. Fixed live with ownership-scoped policies (student/parent/teacher/admin), verified against real accounts (Suresh/teacher, Aarav/student, Papa/parent). |
| Anon-callable finance RPCs | `finance.apply_late_fees()` and `finance.send_fee_reminders()` were `SECURITY DEFINER` and callable by `anon`/`authenticated` via RPC. Revoked from `PUBLIC` (the actual source of the grant). Confirmed `pg_cron` unaffected (jobs run as owner `postgres`, which retains implicit execute). |
| **Live bug found & fixed:** root-level `school_id` claim | 6 SELECT/INSERT policies (`finance.vendors`, `fee_structures`, `payroll_runs`, `purchase_orders`, `vendor_payments`, and `public.students` insert) used `auth.jwt() ->> 'school_id'` — a root-level claim that **does not exist** (school_id only lives in `app_metadata`). This silently blocked ALL client-side reads/inserts on these tables for every real user, including admin. Fixed to match the already-correct `invoices`/`payments` pattern. Verified with a simulated admin JWT: real row counts returned (10 vendors, 27 POs, 75 payroll runs, etc.) where it previously would have been zero. |
| Finance schema migration gap | `supabase/migrations/0002_finance_schema.sql` is a 1-line stub — the entire finance schema (14 objects: 13 tables + `vendor_performance` view) was built live, never captured. **Exported as `0002_finance_schema.sql`** (full replacement), pulled from live `information_schema`/`pg_catalog`. |
| **Bigger drift found:** most of the DB predates/bypassed migrations entirely | Beyond finance, confirmed via `supabase_migrations.schema_migrations.statements` (the CLI's actual record of what ran) that `public.schools`, `public.parent_links`, `public.notifications`, `public.staff_attendance`, all of `academic.announcements/assignments/grades/lesson_resources/submissions`, `communications.messages`, `audit.log`, and the 3 payment enum types were **never in any tracked migration**. `public.students`/`public.staff` are tracked but the tracked version is missing half their live columns (`school_id`, `auth_user_id`, salary fields, etc.). `0004_staff_schema.sql` is tracked as applied but creates a `staff` schema that **does not exist live at all** — dead/orphaned migration. **Exported as `0013_baseline_reconciliation.sql`** (renumbered from a draft "0009" name after this repo snapshot revealed 0009 is already taken twice — see §3). |

### ✅ Resolved in a second follow-up session (2026-07-27, session 3 — repo integration + fee-breakdown UI)

| Item | What happened |
|---|---|
| **Migration-file repo integration** | All three exported SQL files (0002_finance_schema.sql, 0013_baseline_reconciliation.sql, 0014_invoice_line_items.sql) copied into supabase/migrations/ from Downloads. 0004_staff_schema.sql deleted (dead/orphaned). app/supabase/migrations/0009_auth_linkage.sql deleted (redundant — 0013 already has auth_user_id on students/staff). 0001_shared_reference_tables.sql cleaned (removed superseded students/staff CREATE TABLE blocks that would collide with 0013). Apply order: 0001→0002→0003→0005→0006→0007→0008→0010→0011→0012→0013→0014. |
| **Razorpay handler fix** | Moved the success handler (`response.handler`) from being set as `rzp['handler'] = ...` *after* construction to being included in the options object *passed to* the Razorpay constructor — the SDK reads handler during instantiation, not as a later property set. The core `.callMethod('newInstance', [options])` fix from session 2 was preserved. Web-only. |
| **Itemized fee-breakdown UI** | Built inline in parent_fees_screen.dart: student identity block (admission number, name, class from academic.classes.name, roll_no from class_roster), per-fee-head table (11 heads with demo placeholder amounts summing to ₹57,000, clearly commented as demo data), graceful fallback to single invoice amount when no invoice_line_items rows exist, financial summary (scholarship/waiver from waiver_requests, refunds from payments.status, total paid, outstanding). Payment history table: amount, method badge, status, gateway_payment_id, datetime, download-receipt button. Payment query expanded to fetch ALL student payments so refunds appear. |

### ✅ Resolved in a follow-up session (2026-07-27, session 2 — triggered by REAL app testing, not code review)

| Item | What happened |
|---|---|
| **Wrong fee-reminder amount (confirmed live in the actual app)** | Parent (papa@gmail.com) reported a notification saying "₹45000 due" despite having already paid part of the invoice. Root cause found: `finance.send_fee_reminders()` always used the invoice's original `amount_due`, never subtracting `amount_paid` — a real bug affecting every partially-paid invoice in the system, not just this one. **Fixed the function** to use the actual outstanding balance, and corrected the one stale notification already in Aarav Sharma's inbox (now correctly shows ₹29,500). |
| **Itemized fee-breakdown schema gap** | User wants a full fee-breakdown table (Tuition/Admission/Exam/Library/etc. as separate line items on one invoice, matching a specific reference layout). Confirmed via live DB: only 2 `finance.fee_structures` exist at all (Tuition ₹45,000, Transport ₹12,000), and one invoice can only reference ONE `fee_structure_id` — there was no way to represent a multi-line-item invoice. **Built `finance.invoice_line_items`** (new table, exported as `0014_invoice_line_items.sql`) to make this possible. Deliberately did NOT invent fee-head amounts or backfill fake data into real invoices — that's a product decision, not something to fabricate from a DB console. |
| **Razorpay "Pay Online" crash — diagnosed, not fixed (not DB-fixable)** | Real error from live app: `NoSuchMethodError: 'newInstance' ... Instance of 'JsFunction' ... [Instance of 'JSArray<JsObject>']`. This is the classic signature of the `razorpay_flutter` package's native-channel code being invoked on a **web** build, where the package has no real implementation. Confirmed there's already an `app/lib/core/payments/razorpay_web.dart` file (from the crashed Grok session — see below) of unknown completeness. 100% a Flutter/JS-interop issue, zero DB component — handed to Grok with the exact error and diagnosis (see prompt in session transcript / SESSION_LOG once added). |
| **Prior crashed Razorpay session — confirmed partial, uncommitted work exists** | User's screenshot of VS Code / Antigravity source control shows **18 uncommitted changes** since the last real commit, including a new untracked `razorpay_web.dart`, plus modified `pubspec.yaml`/`pubspec.lock`, `env.dart`, `parent_fees_screen.dart`, `app_router.dart`, `nav_config.dart` — consistent with a Razorpay-wiring attempt that crashed before logging or committing. **Unknown** whether these edits are complete, broken, or a mix — some of the 18 changed files (e.g. `announcements_screen.dart`, `emi_financing_screen.dart`, `role_shell.dart`) also correspond to already-completed, already-logged work from earlier sessions that may simply have never been committed. Next agent with repo access should run `git diff` on each file before assuming any of it is either finished or safe to discard. |

### 🟡 Flagged, not changed (judgment calls, left for your decision)
- `communications.messages` — gave admin/principal blanket read access for moderation, matching the pattern already used elsewhere (e.g. grades UPDATE). If you want strictly participant-only messaging with no admin visibility, say so — one-line change.
- `academic.announcements_read` and `public.schools` `schools_read` — still use broad `auth.role() = 'authenticated'`. `schools` is low-risk reference data; `announcements_read` could leak class-targeted announcements outside the class. Not part of the original 7-table security scope, left as-is.

### 📄 Files generated (in `/mnt/user-data/outputs/`, not yet in the repo)
1. **`0002_finance_schema.sql`** — full finance schema export, replaces the stub
2. **`0013_baseline_reconciliation.sql`** — everything else found missing (see table above), correctly numbered to follow the real `0001–0012` sequence
3. **`0014_invoice_line_items.sql`** — new table for the itemized fee-breakdown feature (session 2)
4. **This file** (`context-handoff-brief.md`)

### ⏳ Still open — nothing done yet on these
1. ✅ **~~Repo integration of all three migration files above~~** — Done in session 3.
2. **Not yet tested end-to-end on a fresh instance** — I offered to spin up a temporary Supabase branch and apply `0002` → `0014` there to prove it builds clean from empty, catching ordering/typo issues before commit. Not done yet unless you say go.
3. **Docker port collision** — `document-extraction` and `timetable-solver` both map to `8003:8003` in `docker-compose.yml`. Unresolved.
4. ✅ **~~Razorpay Flutter wiring~~** — Razorpay handler fixed (moved into constructor options), crash diagnosed & fixed. Web-only. Mobile payment is an explicit scope cut.
5. ✅ **~~Itemized fee-breakdown UI~~** — Done in session 3 (see resolved table above).
6. **README.md replacement** — still the stale "Post-Checkpoint Delivery" doc.
7. **Dead file/folder cleanup** — confirmed dead: `teacher_dashboard.dart`, `student_dashboard.dart`, `parent_dashboard.dart` (imported but unrouted); scaffold-only dirs `admissions/`, `attendance/`, `dashboards/`, `finance/`, `predictive_alerts/`, `timetable/` under `app/lib/features/` (all just `.gitkeep`).

---

## 2. Complete project file structure
*(as supplied this session — reflects the actual repo, not a plan)*

```
school-erp/
├── AGENTS.md / CLAUDE.md / GEMINI.md    # synced agent context files
├── README.md                             # ⚠️ still the stale "Post-Checkpoint Delivery" doc
├── .env.example
├── docker-compose.yml                    # ⚠️ port collision: document-extraction & timetable-solver both 8003:8003
├── package.json / package-lock.json
├── .agent-log/
│   ├── SESSION_LOG.md
│   └── archive/SESSION_LOG_pre_20260719.md
├── .github/workflows/ci.yml
├── scripts/sync_agent_files.sh
│
├── app/                                  # Flutter frontend
│   ├── pubspec.yaml / pubspec.lock
│   ├── assets/
│   │   ├── backgrounds/  (4 real JPGs: mountain_trail + study_hall, desktop+mobile)
│   │   └── omr/  (class_8A_template.json, sample_sheet.jpg)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── auth/        (auth_providers, self_children_provider, self_record_provider, user_role, admin_workspace_provider)
│   │   │   ├── config/      (api_endpoints, env)
│   │   │   ├── router/      (app_router.dart, nav_config.dart — Grok-owned)
│   │   │   └── theme/       (app_theme, background_presets, background_preset_provider)
│   │   ├── features/
│   │   │   ├── auth/        (login_screen, splash_screen, unauthorized_screen)
│   │   │   ├── settings/    (settings_screen)
│   │   │   ├── dashboard/   ← the real, wired, active screens
│   │   │   │   ├── admin/       (admin_dashboard, announcements, approval_queue, emi_financing, fee_management, late_fees, messages, offline_payment, payroll, vendor_performance, vendor_procurement, admin_hrm_overview_screen, admin_finance_overview_screen)
│   │   │   │   ├── principal/   (budget_screen, principal_dashboard)
│   │   │   │   ├── teacher/     (gradebook, leave_requests, lesson_resources, teacher_assignments, teacher_attendance, teacher_dashboard*, teacher_summary)
│   │   │   │   ├── student/     (student_assignments, student_dashboard*, student_library, student_overview, student_progress, student_schedule)
│   │   │   │   ├── parent/      (parent_dashboard*, parent_fees, parent_notifications, parent_overview, parent_schedule, waiver_requests)
│   │   │   │   ├── documents/   (document_review_screen)
│   │   │   │   ├── omr/         (omr_upload_screen)
│   │   │   │   └── timetable/   (timetable_grid_screen)
│   │   │   └── [dead scaffolds]: admissions/, attendance/, dashboards/, finance/, predictive_alerts/, timetable/  — all just `.gitkeep`, unused
│   │   ├── shared/
│   │   │   ├── providers/   (empty, .gitkeep)
│   │   │   └── widgets/     (account_not_linked_view, glass_card, progress_ring, role_shell, stat_card, warm_backdrop)
│   │   └── supabase/migrations/0009_auth_linkage.sql   ⚠️ WRONG LOCATION — nested inside app/, separate from the real supabase/migrations/ at root. Easy to miss on a fresh apply. Confirm applied-live status or move+renumber into the real sequence.
│   ├── test/  (omr_upload_screen_test.dart, widget_test.dart)
│   └── web/   (favicon, icons, index.html, manifest.json)
│
├── services/                             # 4 FastAPI microservices
│   ├── document-extraction/  (main.py, extractor.py, Dockerfile, test harness)  ⚠️ port 8003 collision
│   ├── omr-pipeline/          (main.py, scan_omr.py, generate_omr.py, tests, sample_output/)
│   ├── predictive-engine/     (main.py, predictor.py, scripts/ for synthetic-absence seeding)
│   └── timetable-solver/      (main.py, solver.py, Dockerfile)  ⚠️ port 8003 collision
│
├── supabase/                             # backend-of-record
│   ├── config.toml
│   ├── functions/            (4 Edge Functions: attendance-realtime-sync, create-razorpay-order, document-extraction-trigger, razorpay-webhook)
│   ├── migrations/           (0001–0012 at root)
│   │   ├── 0001_shared_reference_tables.sql   ⚠️ tracked version of students/staff is missing columns live has — see §1
│   │   ├── 0002_finance_schema.sql            ⚠️ STALE STUB — replacement generated this session, not yet dropped in
│   │   ├── 0003_academic_schema.sql
│   │   ├── 0004_staff_schema.sql              ⚠️ DEAD — creates a `staff` schema that doesn't exist live at all
│   │   ├── 0005_scheduling_schema.sql         (superseded by 0008 for some objects)
│   │   ├── 0006_attendance_schema.sql
│   │   ├── 0007_documents_schema.sql
│   │   ├── 0008_scheduling_schema_v2.sql      (redefines academic.subjects, scheduling.*)
│   │   ├── 0009-0012                          (see repo for exact names/contents — not all individually audited this session)
│   │   └── 0013_baseline_reconciliation.sql   ⭐ NEW this session — schools, parent_links, notifications, staff_attendance, academic.announcements/assignments/grades/lesson_resources/submissions, communications.messages, audit.log, enums, corrected students/staff. Not yet in repo.
│   ├── policies/README.md
│   └── seed/seed_dummy_data.sql
│
├── docs/
│   ├── architecture.md
│   ├── gap_analysis.md       (real, useful competitor research)
│   └── pitch_decks/README.md (placeholder only, no actual decks committed)
│
├── test/razorpay_checkout_test.html
├── verify_fixes.py
└── verify_screenshots/  (01_splash.png, 02_login.png)
```
`*` = confirmed dead code (`teacher_dashboard.dart`, `student_dashboard.dart`, `parent_dashboard.dart` — imported but no longer routed anywhere).

---

## 3. Known landmines / things to double-check before trusting anything
- **The `0009` name is taken twice**: root `supabase/migrations/` sequence goes 0001–0012 (no gap at 0009), AND there's a separate `app/supabase/migrations/0009_auth_linkage.sql`. Any new migration should start at **0013**, not 0009 — a draft version of this session's baseline export was originally named 0009 and had to be renumbered. Watch for this if any other agent generates a new migration without checking the live sequence first.
- **`0004_staff_schema.sql` is tracked as applied but doesn't exist live.** Migration tracking history (`supabase_migrations.schema_migrations`) is not a reliable proxy for live state on this project — always verify against actual `information_schema`/`pg_catalog`, not just the tracking table.
- **Once `0013` is added, `0001` needs editing** (remove its bare `students`/`staff` `CREATE TABLE`s) or the two will collide on a fresh apply.

---

## 4. Multi-agent handoff protocol — **"NEW-UPDATE"**

**Context this is designed for:** you're running separate browser-based AI chats (multiple
Claude.ai chats, Grok, etc.) — not agents with direct repo/filesystem access to each other.
None of them share memory, and none of them can write to `.agent-log/SESSION_LOG.md` or any
other repo file directly from inside the chat. The **only thing that actually crosses from one
chat to the next is a file you manually upload** — so this brief has to be a fully
self-contained, standalone artifact. No dependency on `SESSION_LOG.md`, no assumption that
the next agent can see anything this one saw.

### The trigger
At the end of a work session, type:
```
NEW-UPDATE
```

### What the agent does
1. Rewrites **this entire file** as a fresh downloadable `.md` — not a diff, not an append-only
   log entry, the whole current-state document regenerated: §1 (current state) updated with
   whatever changed, §2 (file structure) updated if files were added/moved/deleted, a new dated
   entry added to the **Changelog** (§5, below) so history isn't lost even without
   `SESSION_LOG.md`.
2. Prints a short **"paste this to start your next chat"** block in the chat itself — 5-10
   lines, so you can literally copy it into a new chat alongside re-uploading the file, e.g.:
   ```
   Context: School ERP project. Uploading context-handoff-brief.md — read it fully.
   Since last update: <1-2 line summary of what just got done>.
   Top priority right now: <1 line>.
   ```

### How you use it day to day
1. Start a new chat (any AI) → upload the latest `context-handoff-brief.md` → paste the short
   block from step 2 above.
2. Work the session.
3. Before closing, type `NEW-UPDATE` → download the regenerated file → **that's now the
   canonical version** — the one you upload to the *next* chat, wherever it happens.

This makes the `.md` file itself the single source of truth that survives across chats,
tools, and sessions — not any one AI's memory, and not a repo file none of these chats can
actually reach.

### One risk this doesn't solve
If two chats are worked **in parallel** (not sequentially) and both produce a `NEW-UPDATE`,
you'll have two diverged versions of this file with no automatic merge — you'd need to
manually reconcile which changes from each to keep. This protocol assumes roughly sequential
handoff (finish one chat, then start the next), which matches how you described using it. If
you start doing real parallel work across chats, worth flagging that here so I can propose
something more robust (e.g. each chat's `NEW-UPDATE` appending a uniquely-timestamped section
instead of rewriting the whole file, so nothing gets silently overwritten).

### For the agents that DO have repo access (Claude Code, Grok with the repo open)
This same file is still useful to hand them — it's a faster way to get an agent with real
repo access up to speed than making it re-derive everything from `git log`. If such an agent
also updates `.agent-log/SESSION_LOG.md` directly (which it can, and this file can't), that's a
bonus, not a requirement — don't rely on it being in sync with this file.

---

## 5. Changelog
*(Newest first. Added as part of every `NEW-UPDATE`.)*

### 2026-07-28 (Vercel Build, Type Crash, Schema & Layout Fixes)
- Configured Vercel deployment build settings in `vercel.json` (`installCommand`, `buildCommand`, `outputDirectory`) to install Flutter stable SDK, run doctor/config-enable-web, build the web client under `/app`, and output to `/app/build/web`.
- Updated `buildCommand` to pass Vercel environment variables (`$SUPABASE_URL`, `$SUPABASE_ANON_KEY`, `$RAZORPAY_KEY_ID`) via `--dart-define` parameters to resolve compile-time configuration requirements at runtime.
- Fixed runtime `TypeError` crash in `dashboard_provider.dart` where `studentsFuture`, `staffFuture`, etc., were cast to `List` before being resolved by `Future.wait`.
- Fixed runtime type crash in `dashboard_provider.dart` where `timestamp` (already a `DateTime`) was cast `as String?` in sorting comparison.
- Fixed `PostgrestException` database schema mismatch by changing schema context for the `leave_requests` query from `finance` to `public` in `admin_hrm_overview_screen.dart`.
- Fixed the parent Fees screen crash (null check operator on null `_data`) by correcting page load trigger condition `if (_loading && _data == null)` to `if (!_loading && _data == null)` in `parent_fees_screen.dart`.
- Fixed the Messages screen crash by resolving student classes via the `academic.class_roster` junction mapping instead of querying a non-existent `students.class_id` column in `messages_screen.dart`.
- Redesigned and improved parent Overview dashboard layout: modified `ProgressRing` to scale label and subtitle text sizes dynamically to prevent layout clipping and boundary overflow, and structured overview cards to have matched symmetric heights (height 110).
- Refactored `SearchFilterBar` to place clear search and sort options inline inside the search text field's `suffixIcon` as a compact chip dropdown (using `Icons.tune_outlined`), cleaning up layout across all searchable modules.
- Enhanced contrast and visual visibility of the parent dashboard "Quick Links" header label on dark backgrounds by styling it white with a drop shadow.
- Fixed release compilation type mismatch error in `search_filter_bar.dart` by adding explicit `<SortOption>` type parameter to `DropdownMenuItem` inside the mapping list, preventing `List<DropdownMenuItem<dynamic>>` to `List<DropdownMenuItem<SortOption>>` assignment errors during strict `dart2js` build compilation.
- Optimized Vercel build parameters in `vercel.json`: enabled shallow clones (`--depth 1`) to prevent heavy clones/timeouts, wrapped `--dart-define` environment variable configurations in escaped double quotes to safeguard shell parsing against empty/special characters, and prepended a `flutter clean` phase to ensure compile caches are clear.
- Fixed compiler crashes during release builds on constrained Vercel container instances by exporting `DART_VM_OPTIONS="--max-old-space-size=2560"` (forces aggressive garbage collection inside the Dart compiler VM).
- Delegated the Vercel `buildCommand` to a standalone shell script ([build.sh](file:///e:/PROJECTS/school%20erp/school-erp/build.sh)) to resolve Vercel's schema validation error stating that `buildCommand` must not exceed 256 characters (the previous inline shell command was 283 characters).
- Removed the deprecated `--web-renderer` flag from `build.sh` to prevent `Could not find an option named "--web-renderer"` failures, as the latest stable Flutter SDK version (3.29+) has transitioned CanvasKit/SkWasm to be standard and removed the legacy HTML renderer.
- Kept the rewrite rule for client-side routing.


### 2026-07-27 (session 3 — repo integration + fee-breakdown UI build)
- Migration files repo-integrated: 0002 (replaces stub), 0013, 0014 placed in supabase/migrations/; 0004 deleted (dead); app/supabase/migrations/0009 deleted (redundant); 0001 cleaned of superseded students/staff blocks
- Razorpay handler fixed: moved from post-construction property set to constructor options (SDK reads it at instantiation)
- Full itemized fee-breakdown UI built in parent_fees_screen.dart: student identity block, 11-head fee table with demo placeholders (₹57,000 total), fallback to single invoice amount when no line items exist, financial summary (scholarship/refunds/outstanding), payment history table with TX IDs and download-receipt
- All uncommitted work (modified + untracked files) committed to main

### 2026-07-27 (session 2 — triggered by real app testing, not code review)
- Fixed a real, confirmed-live bug: `finance.send_fee_reminders()` used full original invoice amount instead of outstanding balance; corrected the function + the one stale notification already sent
- Diagnosed (not fixed — not DB-fixable) the Razorpay "Pay Online" crash: `razorpay_flutter` called on a web build, confirmed via exact error signature (`JsFunction`/`newInstance`)
- Confirmed via screenshot: a prior Razorpay-wiring session crashed mid-task, leaving 18 uncommitted file changes including an untracked `razorpay_web.dart` — status unverified, flagged for `git diff` review before building on or discarding
- Built `finance.invoice_line_items` (exported as `0014_invoice_line_items.sql`) to make itemized fee-breakdown invoices possible — schema only, no fake data backfilled
- Drafted Grok prompt covering both the Razorpay crash fix and the fee-breakdown UI build

### 2026-07-27 (session 1)
- RLS fixed on 7 tables (grades/submissions/class_roster/assignments/subjects/lesson_resources/messages)
- Anon-callable finance RPCs locked down (`apply_late_fees`, `send_fee_reminders`)
- Found + fixed live bug: root-level `school_id` JWT claim (doesn't exist) silently blocking reads on 6 tables
- Finance schema exported (`0002_finance_schema.sql`, replaces stale stub)
- Bigger drift found + exported: `0013_baseline_reconciliation.sql` (schools, parent_links, notifications, staff_attendance, academic.* gaps, communications.messages, audit.log, enums, corrected students/staff)
- Caught and fixed a migration-numbering collision (draft "0009" → renumbered to real next-free slot, `0013`)
- This handoff-protocol redesigned around standalone-file handoff (no repo/session-log dependency), replacing an earlier draft that assumed shared repo access
