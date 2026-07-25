# School ERP — Flutter App

Role-based dashboards (Principal/Admin/Teacher/Student/Parent), one codebase, per
`AGENTS.md`. Built fresh per your instruction to have something complete you can drop
straight into the repo.

## Placement

This whole folder replaces/merges into your existing `app/` directory:

```
school-erp/
  app/
    pubspec.yaml
    lib/
      main.dart
      core/
        config/env.dart
        theme/app_theme.dart
        auth/
          user_role.dart
          auth_providers.dart
          self_record_provider.dart
        router/app_router.dart
      features/
        auth/
          login_screen.dart
          splash_screen.dart
          unauthorized_screen.dart
        dashboard/
          principal/principal_dashboard.dart
          admin/admin_dashboard.dart
          teacher/teacher_dashboard.dart
          student/student_dashboard.dart
          parent/parent_dashboard.dart
      shared/
        widgets/
          role_scaffold.dart
          stat_card.dart
          account_not_linked_view.dart
    supabase/
      migrations/0009_auth_linkage.sql   <- NOT applied, review first
```

If `app/lib/core/router.dart` already exists from your teammate's earlier stub, back it
up before overwriting — check whether it has work in progress worth keeping first.

## Setup

```powershell
cd app
flutter pub get
```

Run with your Supabase **anon** key (never the service-role key — see the warning in
`lib/core/config/env.dart`):

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://yhcyhwpdgqupylrnkqht.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

For repeated runs, put these in a **git-ignored** `dart_define.json` and use
`--dart-define-from-file=dart_define.json` instead.

## ⚠️ I could not test or compile this

This environment has no Flutter/Dart SDK, so unlike the Python backend services (which
were actually run and verified against your live DB), **this code has never been
compiled or run**. Before trusting it:

```powershell
flutter analyze
flutter run
```

Fix whatever `flutter analyze` surfaces first — package version mismatches (the
`^2.5.1`-style version constraints in `pubspec.yaml` are reasonable as of this build
but Flutter package versions move fast; run `flutter pub outdated` if `pub get` fails
to resolve) are the most likely first issue, not logic errors.

## What's fully built and working (once you provide real Supabase credentials)

- **Auth**: email/password sign-in via Supabase Auth, session-aware routing
- **Routing**: `go_router` with auth-aware redirects — signed-out users only reach
  `/login`; signed-in users are routed to their role's dashboard automatically, no
  manual navigation calls scattered around
- **Principal Dashboard**: real school-wide stats — student count, staff count, fee
  collection (from `finance.invoices`), timetable slot count. Queries your actual live
  schema, same `.schema('...').from('...')` pattern as the backend services
- **Admin Dashboard**: recent payments list from `finance.payments`
- **Theme**: consistent Material 3 theme, light + dark

## What's built but deliberately gated — read this before assuming it's broken

**There is currently no way to know which `public.staff` or `public.students` row a
logged-in Supabase Auth user corresponds to.** Neither table has an `auth_user_id` or
`email` column (verified against your live schema). So:

- **Teacher Dashboard** and **Student Dashboard** are fully wired (auth, routing, nav
  shell) but show an honest "account not linked yet" state instead of either (a)
  guessing the link by matching names, which breaks the moment two people share a
  name, or (b) showing everyone's data, which is a privacy bug.
- **`supabase/migrations/0009_auth_linkage.sql`** fixes this — adds a nullable
  `auth_user_id` column to both tables. **Not applied** — review and run it yourself,
  then swap in the real query in `core/auth/self_record_provider.dart` (the exact
  query is written out in that file's comments, ready to uncomment/adapt).

## Auth ↔ domain data linkage — the one real product decision left

Three separate things are bundled under "auth," and they need different answers:

1. **Role** (Principal/Admin/Teacher/Student/Parent) — assumed to live in
   `app_metadata.role` as a JWT custom claim, following the same pattern your `staff`
   RLS policy already uses for `school_id`. **Not yet verified against a real
   configured Supabase Auth Hook** — no such hook exists in the live project yet. You
   (or Grok) need to either configure one, or set `app_metadata` manually per user via
   the Supabase dashboard for testing.
2. **Staff/Student linkage** — solved by the migration above, once applied + a
   real-world way to populate it (an admin "link account" flow, or set at invite time).
3. **Parent↔Child linkage** — genuinely unsolved, and I didn't invent an answer.
   `public.students` has no structured parent relationship, only a free-text
   `guardian_contact` field. Does one student have exactly one parent account (simple,
   probably wrong for many real families), or many? Is a parent-student link table the
   right shape? This is a product decision, not a technical one — decide it before
   anyone builds the Parent dashboard's real data views.

## Not built (explicitly out of scope for this pass)

- Any of the actual feature UIs beyond navigation shells — e.g. a real timetable grid
  view, an OMR upload screen, a substitute-recommendation review screen. Those need
  their own screens built once the linkage question above is resolved for
  teacher/student, and once you decide what each role's IA (navigation structure)
  should actually contain beyond the one overview screen each has now.
- Offline support, push notifications, deep linking beyond the five dashboard routes.
- Any styling beyond a functional, consistent baseline — this is a solid foundation to
  build real screens on, not a finished, polished product.
