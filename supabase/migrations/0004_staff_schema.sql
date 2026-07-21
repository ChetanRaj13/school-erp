create schema if not exists staff;

create table if not exists staff.leave_requests (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid references public.staff(id),
  leave_type text,
  from_date date,
  to_date date,
  status text default 'pending' check (status in ('pending','approved','rejected')),
  approved_by uuid references public.staff(id)
);

alter table staff.leave_requests enable row level security;
