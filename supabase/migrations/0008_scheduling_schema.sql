-- Migration: 0008_scheduling_schema
-- Applies scheduling schema + academic.subjects + test seeds
-- Applied live via: npx supabase db push --linked

create schema if not exists scheduling;

-- ── Subjects ──────────────────────────────────────────────────
create table if not exists academic.subjects (
  id               uuid primary key default gen_random_uuid(),
  class_id         uuid references academic.classes(id),
  name             text not null,
  code             text,
  periods_per_week int not null default 5 check (periods_per_week > 0),
  is_core          boolean not null default false
);

alter table academic.subjects enable row level security;
create policy subjects_read on academic.subjects
  for select using (auth.role() = 'authenticated');

-- ── Teacher-subject qualifications ─────────────────────────────
create table if not exists scheduling.teacher_subjects (
  id           uuid primary key default gen_random_uuid(),
  teacher_id   uuid not null references public.staff(id) on delete cascade,
  subject_id   uuid not null references academic.subjects(id) on delete cascade,
  created_at   timestamptz default now(),
  unique(teacher_id, subject_id)
);

alter table scheduling.teacher_subjects enable row level security;
create policy ts_read on scheduling.teacher_subjects
  for select using (auth.role() = 'authenticated');

-- ── Rooms ──────────────────────────────────────────────────────
create table if not exists scheduling.rooms (
  id   uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null
);

alter table scheduling.rooms enable row level security;
create policy rooms_read on scheduling.rooms
  for select using (auth.role() = 'authenticated');

-- ── Time slots (reference table) ───────────────────────────────
-- Pre-seeded Mon-Fri x Period 1-6 = 30 slots
create table if not exists scheduling.time_slots (
  id              serial primary key,
  day             text not null check (day in ('mon','tue','wed','thu','fri')),
  period_number   int not null check (period_number > 0 and period_number <= 6),
  start_time      time not null,
  end_time        time not null,
  unique(day, period_number)
);

alter table scheduling.time_slots enable row level security;
create policy ts_slots_read on scheduling.time_slots
  for select using (auth.role() = 'authenticated');

-- ── Timetable (solver output) ──────────────────────────────────
create table if not exists scheduling.timetable (
  id          uuid primary key default gen_random_uuid(),
  class_id    uuid not null references academic.classes(id),
  subject_id  uuid not null references academic.subjects(id),
  teacher_id  uuid not null references public.staff(id),
  slot_id     int not null references scheduling.time_slots(id),
  room_id     uuid references scheduling.rooms(id),
  is_reviewed boolean not null default false,
  reviewed_by uuid references public.staff(id),
  reviewed_at timestamptz,
  created_at  timestamptz default now()
);

alter table scheduling.timetable enable row level security;
create policy tt_read on scheduling.timetable
  for select using (auth.role() = 'authenticated');

-- ── Substitutions ──────────────────────────────────────────────
create table if not exists scheduling.substitutions (
  id                    uuid primary key default gen_random_uuid(),
  original_teacher_id   uuid not null references public.staff(id),
  substitute_teacher_id uuid references public.staff(id),
  date                  date not null,
  slot_id               int not null references scheduling.time_slots(id),
  class_id              uuid not null references academic.classes(id),
  status                text not null default 'proposed' check (status in ('proposed','confirmed','cancelled')),
  created_at            timestamptz default now()
);

alter table scheduling.substitutions enable row level security;
create policy sub_read on scheduling.substitutions
  for select using (auth.role() = 'authenticated');

-- HINT: GRANT USAGE ON SCHEMA scheduling TO anon, authenticated, service_role;

-- ═══════════════════════════════════════════════════════════
-- SEED DATA
-- ═══════════════════════════════════════════════════════════

-- Class 9-A (8-A already seeded from migration 0003)
insert into academic.classes (id, name)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '9-A')
on conflict do nothing;

-- Subjects for 8-A
insert into academic.subjects (class_id, name, code, periods_per_week, is_core) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Mathematics',   'MATH', 5, true),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Science',       'SCI',  4, true),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'English',       'ENG',  5, true),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Social Studies','SS',   3, false),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Hindi',         'HI',   4, false),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Physical Ed.',  'PE',   2, false)
on conflict do nothing;

-- Subjects for 9-A
insert into academic.subjects (class_id, name, code, periods_per_week, is_core) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Mathematics',   'MATH', 5, true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Physics',       'PHY',  4, true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Chemistry',     'CHEM', 4, true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'English',       'ENG',  3, true),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Biology',       'BIO',  3, false),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Hindi',         'HI',   3, false)
on conflict do nothing;

-- Rooms
insert into scheduling.rooms (name, type) values
  ('Classroom 1', 'classroom'),
  ('Classroom 2', 'classroom'),
  ('Classroom 3', 'classroom')
on conflict do nothing;

-- Time slots: Mon-Fri x Period 1-6
-- Period 1: 8:30-9:10, P2: 9:10-9:50, Break, P3: 10:05-10:45, P4: 10:45-11:25, P5: 11:25-12:05, Lunch, P6: 12:35-13:15
insert into scheduling.time_slots (day, period_number, start_time, end_time) values
  ('mon',1,'08:30','09:10'),('mon',2,'09:10','09:50'),('mon',3,'10:05','10:45'),('mon',4,'10:45','11:25'),('mon',5,'11:25','12:05'),('mon',6,'12:35','13:15'),
  ('tue',1,'08:30','09:10'),('tue',2,'09:10','09:50'),('tue',3,'10:05','10:45'),('tue',4,'10:45','11:25'),('tue',5,'11:25','12:05'),('tue',6,'12:35','13:15'),
  ('wed',1,'08:30','09:10'),('wed',2,'09:10','09:50'),('wed',3,'10:05','10:45'),('wed',4,'10:45','11:25'),('wed',5,'11:25','12:05'),('wed',6,'12:35','13:15'),
  ('thu',1,'08:30','09:10'),('thu',2,'09:10','09:50'),('thu',3,'10:05','10:45'),('thu',4,'10:45','11:25'),('thu',5,'11:25','12:05'),('thu',6,'12:35','13:15'),
  ('fri',1,'08:30','09:10'),('fri',2,'09:10','09:50'),('fri',3,'10:05','10:45'),('fri',4,'10:45','11:25'),('fri',5,'11:25','12:05'),('fri',6,'12:35','13:15')
on conflict (day, period_number) do nothing;

-- Class roster for 9-A (Aarav + Diya mapped to 9-A too)
insert into academic.class_roster (class_id, student_id, roll_no) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333331', 1),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '33333333-3333-3333-3333-333333333332', 2)
on conflict do nothing;
