-- 0009_auth_linkage.sql
-- NOT APPLIED. Review before running — this is the fix for the "which staff/student
-- row belongs to this logged-in user" gap flagged throughout the Flutter app build
-- (see app/README.md's "Auth ↔ domain data linkage" section).
--
-- WHY NULLABLE, NOT NOT NULL: existing staff/student rows have no auth user yet
-- (they were seeded directly via SQL, never signed up through Supabase Auth). Making
-- this NOT NULL would break on apply. Nullable + a follow-up "link my account" flow
-- (or manual admin linking) is the safe path — same reasoning the project already
-- applied to scheduling.timetable.room_id (nullable) and other optional FKs.

alter table public.staff
  add column if not exists auth_user_id uuid references auth.users(id);

alter table public.students
  add column if not exists auth_user_id uuid references auth.users(id);

-- Prevents two staff/student rows from ever claiming the same auth user.
create unique index if not exists staff_auth_user_id_unique
  on public.staff (auth_user_id) where auth_user_id is not null;

create unique index if not exists students_auth_user_id_unique
  on public.students (auth_user_id) where auth_user_id is not null;

-- OPTIONAL, NOT INCLUDED HERE ON PURPOSE: RLS policies scoped to "auth.uid() =
-- auth_user_id" for self-service reads (e.g. a teacher reading their own staff row
-- directly). Not added in this migration because the app currently authenticates via
-- the anon key + these new columns for CLIENT-SIDE query filtering (e.g.
-- .eq('auth_user_id', uid)), and existing RLS policies (school_id = auth.jwt()->>
-- 'school_id') already govern row visibility at the school level. Add self-scoped
-- policies separately if "a teacher can read only their own staff row, not the whole
-- staff table" becomes a real requirement — that's a deliberate follow-up decision,
-- not an oversight.

-- STILL UNSOLVED BY THIS MIGRATION: parent↔student linking. A parent doesn't map to
-- one staff/student row the way a teacher or student does — they map to their CHILD's
-- student row, and public.students has no structured parent relationship (only a
-- free-text guardian_contact field). That needs a real design decision (see
-- ParentDashboard's doc comment in the Flutter app) before a similar migration can be
-- written for it.
