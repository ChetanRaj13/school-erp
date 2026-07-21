create schema if not exists attendance;

create table if not exists attendance.records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.students(id),
  staff_id uuid references public.staff(id),      -- null if this row is a student record
  class_id uuid references academic.classes(id),
  date date not null,
  status text check (status in ('present','absent','half_day','on_leave')),
  method text check (method in ('manual','omr','app_checkin')),
  confidence numeric(3,2),                          -- for OMR: fill-detection confidence
  needs_review boolean default false,
  marked_by uuid references public.staff(id),
  created_at timestamptz default now()
);

create table if not exists attendance.school_settings (
  id uuid primary key default gen_random_uuid(),
  attendance_mode text default 'both' check (attendance_mode in ('manual','omr','both'))
);

alter table attendance.records enable row level security;
alter table attendance.school_settings enable row level security;
