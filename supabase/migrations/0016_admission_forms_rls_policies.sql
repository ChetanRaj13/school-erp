-- ============================================================================
-- 0016_admission_forms_rls_policies.sql
--
-- Adds missing RLS policies on documents.admission_forms. The table was created
-- with `enable row level security` but zero policies, meaning only the
-- service-role key (used by the document-extraction microservice) could access
-- it — the Flutter app (using the anon/authenticated key) could not read or
-- update any rows.
--
-- Since documents.admission_forms has no direct `school_id` column, school
-- scoping is done via a join through student_id -> public.students.school_id,
-- matching the pattern already established in finance.invoices and other tables
-- that scope through a related table.
--
-- No INSERT policy is needed for authenticated users — the only code path that
-- inserts into admission_forms is the document-extraction microservice, which
-- uses the service-role key and bypasses RLS entirely.
-- ============================================================================

-- Admin/principal can view all admission forms for students in their school.
create policy admission_forms_select on documents.admission_forms
  for select
  using (
    ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal'])
    and exists (
      select 1 from public.students s
      where s.id = admission_forms.student_id
        and s.school_id = (((auth.jwt() -> 'app_metadata'::text) ->> 'school_id'::text))::uuid
    )
  );

-- Admin/principal can update review status/fields on forms for students in their school.
create policy admission_forms_update on documents.admission_forms
  for update
  using (
    ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal'])
    and exists (
      select 1 from public.students s
      where s.id = admission_forms.student_id
        and s.school_id = (((auth.jwt() -> 'app_metadata'::text) ->> 'school_id'::text))::uuid
    )
  )
  with check (
    ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal'])
    and exists (
      select 1 from public.students s
      where s.id = admission_forms.student_id
        and s.school_id = (((auth.jwt() -> 'app_metadata'::text) ->> 'school_id'::text))::uuid
    )
  );

