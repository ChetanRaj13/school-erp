-- Shared identity tables that every domain schema links back to via FK.
-- Do NOT duplicate student/staff identity fields inside domain schemas —
-- reference these tables instead.

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  class_id uuid,           -- fk added once academic schema exists
  parent_id uuid,          -- fk to auth.users / a parents table
  created_at timestamptz default now()
);

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  role text not null check (role in ('principal','admin','teacher','accountant','other')),
  created_at timestamptz default now()
);
