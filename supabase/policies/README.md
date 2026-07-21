# RLS Policies

One file per schema (e.g. `finance.sql`, `attendance.sql`) defining role-scoped
row-level-security policies. Every table created in /supabase/migrations must
have a matching policy here before it's considered done — see AGENTS.md
hard rules ("never expose cross-student/cross-staff data by default").

Pattern to follow per table:
- Parents can only select rows where student_id belongs to their own child(ren)
- Teachers can only select/update rows for classes they teach
- Admin/Principal roles get broader read access, still scoped to their own school
