// Role-based routing lives here.
// After login, read the user's role from Supabase (auth metadata / profiles
// table) and route to the matching dashboard shell:
//   principal -> features/dashboards/principal
//   admin     -> features/dashboards/admin
//   teacher   -> features/dashboards/teacher
//   student   -> features/dashboards/student
//   parent    -> features/dashboards/parent
//
// Use go_router with a redirect() based on a Riverpod currentUserRoleProvider.
