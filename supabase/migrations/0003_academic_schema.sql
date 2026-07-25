-- Applied to live DB: 2026-07-22
-- academic schema: classes + class_roster (roll_no <-> student_id mapping for OMR)

create schema if not exists academic;

create table if not exists academic.classes (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,             -- e.g. "8-A"
  class_teacher_id uuid references public.staff(id),
  created_at       timestamptz default now()
);

alter table academic.classes enable row level security;

-- Roster: maps (class_id, roll_no) -> student_id
-- Used by OMR pipeline to resolve roll numbers to student UUIDs.
-- UNIQUE on (class_id, roll_no): one student per roll per class.
-- UNIQUE on (class_id, student_id): one roll per student per class.
create table if not exists academic.class_roster (
  id         uuid primary key default gen_random_uuid(),
  class_id   uuid not null references academic.classes(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  roll_no    int  not null,
  created_at timestamptz default now(),
  unique (class_id, roll_no),
  unique (class_id, student_id)
);

alter table academic.class_roster enable row level security;

create policy roster_read on academic.class_roster
  for select using (auth.role() = 'authenticated');

create table if not exists academic.subjects (
  id               uuid primary key default gen_random_uuid(),
  class_id         uuid references academic.classes(id),
  name             text not null,
  periods_per_week int default 5
);

alter table academic.subjects enable row level security;

-- Seed: Class 8-A (matches sample OMR sheet in services/omr-pipeline/sample_output/)
insert into academic.classes (id, name)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '8-A')
on conflict do nothing;

-- Seed roster: Aarav Sharma = roll 1, Diya Patel = roll 2
insert into academic.class_roster (class_id, student_id, roll_no)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333331', 1),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333332', 2)
on conflict do nothing;

-- PostgREST exposure: academic added to schemas[] in supabase/config.toml
-- GRANT USAGE ON SCHEMA academic TO anon, authenticated, service_role; (applied live)
