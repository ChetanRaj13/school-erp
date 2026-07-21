create schema if not exists academic;

create table if not exists academic.classes (
  id uuid primary key default gen_random_uuid(),
  name text not null,          -- e.g. "8-A"
  class_teacher_id uuid references public.staff(id)
);

create table if not exists academic.subjects (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references academic.classes(id),
  name text not null,
  periods_per_week int default 5
);

alter table academic.classes enable row level security;
alter table academic.subjects enable row level security;
