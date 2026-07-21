create schema if not exists scheduling;

create table if not exists scheduling.timetable (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references academic.classes(id),
  subject_id uuid references academic.subjects(id),
  teacher_id uuid references public.staff(id),
  day text check (day in ('mon','tue','wed','thu','fri','sat')),
  slot int not null,
  room text
);

create table if not exists scheduling.substitutions (
  id uuid primary key default gen_random_uuid(),
  original_teacher_id uuid references public.staff(id),
  substitute_teacher_id uuid references public.staff(id),
  date date not null,
  slot int not null,
  class_id uuid references academic.classes(id),
  status text default 'confirmed'
);

alter table scheduling.timetable enable row level security;
alter table scheduling.substitutions enable row level security;
