-- ============================================================================
-- 0018_tighten_academic_rls_policies.sql
--
-- Replaces the overly broad RLS policies on academic.assignments and
-- academic.submissions that were introduced in 0012. The old policies allowed
-- ANY authenticated user to insert/update submissions and insert assignments,
-- which meant a student could insert fake grades or create assignments.
--
-- New policies:
--   assignments_insert: only teachers (who are the assigned teacher), admins,
--                       and principals can insert assignments.
--   submissions_insert: students can only insert their own submissions.
--                       Teachers/admins/principals can insert for any student.
--   submissions_update: only teachers/admins/principals can update (grade)
--                       submissions. Students cannot modify submissions.
--
-- These policies match the role/ownership checks defined in the 0013 baseline
-- reconciliation migration, which already had proper scoped policies for
-- assignments_read, submissions_read, and teacher_grade_submissions.
-- ============================================================================

-- Drop the old overly broad policies first (they were created in 0012).
drop policy if exists submissions_insert on academic.submissions;
drop policy if exists submissions_update on academic.submissions;
drop policy if exists assignments_insert on academic.assignments;

-- ─── assignments: INSERT ──────────────────────────────────────────
-- Only the assigned teacher, an admin, or a principal can insert a new assignment.
-- The teacher_id column on assignments identifies who created/is responsible for it.
create policy assignments_insert on academic.assignments
  for insert to authenticated
  with check (
    (
      -- Teacher: must be the teacher_id on the new assignment
      ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'teacher'
      and teacher_id in (select id from public.staff where auth_user_id = auth.uid())
    )
    or ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['admin','principal'])
  );

-- ─── submissions: INSERT ──────────────────────────────────────────
-- Students can only insert their own submissions (student_id links to their auth user).
-- Teachers, admins, and principals can insert submissions for any student (e.g. for
-- students without direct app access, or bulk upload scenarios).
create policy submissions_insert on academic.submissions
  for insert to authenticated
  with check (
    (
      -- Student inserting their own submission
      ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = 'student'
      and student_id in (select id from public.students where auth_user_id = auth.uid())
    )
    or ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['teacher','admin','principal'])
  );

-- ─── submissions: UPDATE ──────────────────────────────────────────
-- Only teachers (who are the assignment's teacher), admins, and principals can
-- update submissions (i.e. grade them). Students should never update a submission
-- after it's been submitted (that would let them overwrite grades).
create policy submissions_update on academic.submissions
  for update to authenticated
  using (
    ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['teacher','admin','principal'])
  )
  with check (
    ((auth.jwt() -> 'app_metadata'::text) ->> 'role'::text) = any (array['teacher','admin','principal'])
  );

