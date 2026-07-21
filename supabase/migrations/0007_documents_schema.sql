create schema if not exists documents;

create table if not exists documents.admission_forms (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.students(id),
  original_image_url text not null,
  extracted_json jsonb,
  uncertain_fields text[],
  status text default 'pending_review' check (status in ('pending_review','verified','rejected')),
  extracted_by text default 'ai',
  reviewed_by uuid references public.staff(id),
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

alter table documents.admission_forms enable row level security;
