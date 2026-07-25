-- Migration: 0010_documents_schema_fix
-- Creates documents.admission_forms (idempotent) + real role-scoped RLS policy.
-- 0007 was tracked in schema_migrations but the table never landed — this fixes that.
-- Applied via: npx supabase db push --linked

create schema if not exists documents;

create table if not exists documents.admission_forms (
  id                 uuid primary key default gen_random_uuid(),
  student_id         uuid references public.students(id),
  original_image_url text not null,
  extracted_json     jsonb,
  uncertain_fields   text[],
  status             text not null default 'pending_review'
                       check (status in ('pending_review','verified','rejected')),
  extracted_by       text not null default 'ai',
  reviewed_by        uuid references public.staff(id),
  reviewed_at        timestamptz,
  created_at         timestamptz not null default now()
);

alter table documents.admission_forms enable row level security;

-- Authenticated users (admin/principal reviewing forms) can read pending drafts.
-- Writes go through the service-role-backed API only (bypasses RLS by design).
create policy af_read on documents.admission_forms
  for select using (auth.role() = 'authenticated');

grant usage on schema documents to anon, authenticated, service_role;
grant select on documents.admission_forms to authenticated;
grant all    on documents.admission_forms to service_role;
