-- Minimal seed data for local dev / demo. Do NOT run against production.
insert into public.staff (full_name, role) values
  ('Demo Principal', 'principal'),
  ('Demo Admin', 'admin'),
  ('Demo Teacher', 'teacher')
on conflict do nothing;
