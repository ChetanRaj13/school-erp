/// Mirrors public.staff.role's real values (verified live: 'principal', 'admin',
/// 'teacher' — 'accountant' role also seen in seed data, mapped to admin-level access
/// below since it's finance-focused; adjust if a dedicated Accountant dashboard is
/// ever needed). Plus 'student' and 'parent', which aren't in public.staff at all —
/// those two roles will need their own identification once the auth-linkage gap
/// (see README) is resolved, since students/parents aren't staff rows.
enum UserRole {
  principal,
  admin,
  teacher,
  student,
  parent,
  unknown;

  static UserRole fromString(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'principal':
        return UserRole.principal;
      case 'admin':
      case 'accountant': // finance-focused staff role, routed to the admin dashboard for now
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      case 'parent':
        return UserRole.parent;
      default:
        return UserRole.unknown;
    }
  }

  String get label {
    switch (this) {
      case UserRole.principal:
        return 'Principal';
      case UserRole.admin:
        return 'Admin';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      case UserRole.parent:
        return 'Parent';
      case UserRole.unknown:
        return 'Unknown';
    }
  }

  /// Route path this role lands on after login. Kept here (not scattered across the
  /// router) so role→destination is defined in exactly one place.
  String get homeRoute {
    switch (this) {
      case UserRole.principal:
        return '/principal';
      case UserRole.admin:
        return '/admin';
      case UserRole.teacher:
        return '/teacher';
      case UserRole.student:
        return '/student';
      case UserRole.parent:
        return '/parent';
      case UserRole.unknown:
        return '/unauthorized';
    }
  }
}
