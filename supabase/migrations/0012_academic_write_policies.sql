-- Fix: add INSERT/UPDATE policies on academic tables so teachers can actually
-- grade submissions and post assignments. The previous migration only granted
-- SELECT, so all writes were silently rejected by RLS.

-- ─── submissions ───────────────────────────────────────────────────────────────
-- Teachers need UPDATE to grade, and students need INSERT to submit.
-- For the hackathon, a broad "authenticated" policy matches the existing
-- read-only pattern; tighten to role checks before production.

create policy submissions_insert on academic.submissions
  for insert to authenticated
  with check (auth.role() = 'authenticated');

create policy submissions_update on academic.submissions
  for update to authenticated
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- ─── assignments ───────────────────────────────────────────────────────────────
-- Teachers need INSERT to post assignments.

create policy assignments_insert on academic.assignments
  for insert to authenticated
  with check (auth.role() = 'authenticated');

-- ─── grants ────────────────────────────────────────────────────────────────────
-- GRANT SELECT already exists from 0011; add INSERT + UPDATE.

grant insert, update on academic.submissions to authenticated;
grant insert on academic.assignments to authenticated;
