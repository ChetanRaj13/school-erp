-- 0011_academic_comms_leave_schema.sql
-- ALREADY APPLIED LIVE (via Supabase MCP, verified: all 5 tables + RLS + grants
-- confirmed present). This file exists for repo/migration-history consistency —
-- running it again is safe (all statements use IF NOT EXISTS / are idempotent-safe
-- for a fresh apply), but it's not required for the live DB to work correctly right now.
--
-- WHY THESE 5 TABLES: the feature file's Teacher/Student/Parent Core features
-- (homework/assignments, gradebook, announcements, direct messaging, leave requests)
-- had ZERO backing schema before this — not even a stub. Rather than build UI against
-- invented/fake data, this adds the minimum real schema needed, matching the
-- conventions already established elsewhere in this project (uuid PKs, RLS enabled +
-- real auth.role()='authenticated' policy — not a USING(true) stub, explicit grants
-- for authenticated/anon, matching the scheduling/documents schema pattern).
--
-- DELIBERATELY MINIMAL — this is not a finished academic/comms system:
-- - submissions.grade is a free-text field, not a structured gradebook with
--   weighting/rubrics — sufficient for "view your grade," not for a full gradebook
--   feature. Extend later if real gradebook computation is needed.
-- - communications.messages is a flat 1:1 message table (staff<->student), no threads/
--   group conversations. The two-nullable-FK-with-check pattern (exactly one of
--   sender_staff_id/sender_student_id set) lets either a staff member or a student
--   send a message without a separate polymorphic "users" table — matches this
--   project's existing preference for simple, explicit schema over abstraction.
-- - No notification delivery (push/in-app) wired to any of these — AGENTS.md's
--   cross-cutting "Notification system" is a separate, unbuilt piece of
--   infrastructure, not something this migration attempts.

create schema if not exists communications;

create table if not exists academic.assignments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references academic.classes(id),
  subject_id uuid not null references academic.subjects(id),
  teacher_id uuid not null references public.staff(id),
  title text not null,
  description text,
  due_date date not null,
  created_at timestamptz not null default now()
);

create table if not exists academic.submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references academic.assignments(id),
  student_id uuid not null references public.students(id),
  file_url text,
  status text not null default 'submitted' check (status in ('submitted','graded')),
  grade text,
  feedback text,
  submitted_at timestamptz not null default now(),
  unique (assignment_id, student_id)
);

create table if not exists academic.announcements (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id),
  class_id uuid references academic.classes(id), -- null = school-wide announcement
  author_staff_id uuid not null references public.staff(id),
  title text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists communications.messages (
  id uuid primary key default gen_random_uuid(),
  sender_staff_id uuid references public.staff(id),
  sender_student_id uuid references public.students(id),
  recipient_staff_id uuid references public.staff(id),
  recipient_student_id uuid references public.students(id),
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (num_nonnulls(sender_staff_id, sender_student_id) = 1),
  check (num_nonnulls(recipient_staff_id, recipient_student_id) = 1)
);

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id),
  start_date date not null,
  end_date date not null,
  reason text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  approved_by uuid references public.staff(id),
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);

alter table academic.assignments enable row level security;
alter table academic.submissions enable row level security;
alter table academic.announcements enable row level security;
alter table communications.messages enable row level security;
alter table public.leave_requests enable row level security;

-- Read-only for all authenticated users at the RLS level, matching the same broad
-- (not yet school-scoped) pattern already flagged as a known gap on
-- scheduling.timetable/substitutions earlier tonight. Same tradeoff applies here:
-- fine for a single-school hackathon demo, worth tightening before multi-school use.
create policy assignments_read on academic.assignments for select using (auth.role() = 'authenticated');
create policy submissions_read on academic.submissions for select using (auth.role() = 'authenticated');
create policy announcements_read on academic.announcements for select using (auth.role() = 'authenticated');
create policy messages_read on communications.messages for select using (auth.role() = 'authenticated');
create policy leave_requests_read on public.leave_requests for select using (auth.role() = 'authenticated');

grant usage on schema communications to authenticated, anon;
grant select on all tables in schema academic to authenticated, anon;
grant select on all tables in schema communications to authenticated, anon;
grant select on public.leave_requests to authenticated, anon;
alter default privileges in schema academic grant select on tables to authenticated, anon;
alter default privileges in schema communications grant select on tables to authenticated, anon;

-- NOT INCLUDED: INSERT/UPDATE policies for authenticated users. All writes (teacher
-- posting an assignment, student submitting, staff sending a message, staff
-- requesting leave) currently need to go through a service-role-backed endpoint,
-- same as every other write path in this project (timetable /commit,
-- substitutes/commit, documents/commit). Add scoped INSERT/UPDATE policies only if a
-- direct-from-Flutter write path is deliberately chosen instead — not done here by
-- default, since AGENTS.md's human-in-the-loop pattern favors reviewed writes through
-- a backend, not direct client writes.
