-- Applied to live DB: 2026-07-22
-- attendance schema: records (OMR + manual + app_checkin) + school_settings
-- DEPENDS ON: academic schema (0003_academic_schema.sql must run first)

create schema if not exists attendance;

create table if not exists attendance.records (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid references public.students(id),
  -- NOTE: staff_id removed (staff attendance is future scope, not built yet)
  class_id      uuid references academic.classes(id),
  date          date not null,
  status        text check (status in ('present','absent','half_day','on_leave')),
  method        text check (method in ('manual','omr','app_checkin')) default 'omr',
  confidence    numeric(4,3),            -- OMR: fill-detection confidence (0.000–1.000)
  needs_review  boolean default false,
  review_reason text,                    -- why review is needed (e.g. "no roster match for roll_no 5")
  marked_by     uuid references public.staff(id),   -- null for OMR auto-scan
  created_at    timestamptz default now()
);

alter table attendance.records enable row level security;

create policy records_read on attendance.records
  for select using (auth.role() = 'authenticated');
-- NOTE: inserts are done via service-role client (bypasses RLS) in the OMR FastAPI service

create table if not exists attendance.school_settings (
  id              uuid primary key default gen_random_uuid(),
  attendance_mode text default 'both' check (attendance_mode in ('manual','omr','both'))
);

alter table attendance.school_settings enable row level security;

-- PostgREST exposure: attendance added to schemas[] in supabase/config.toml
-- GRANT USAGE ON SCHEMA attendance TO anon, authenticated, service_role; (applied live)
