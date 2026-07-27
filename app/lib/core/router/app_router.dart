import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/unauthorized_screen.dart';
import '../../features/dashboard/principal/principal_dashboard.dart';
import '../../features/dashboard/principal/budget_screen.dart';
import '../../features/dashboard/admin/admin_dashboard.dart';
import '../../features/dashboard/admin/admin_finance_overview_screen.dart';
import '../../features/dashboard/admin/admin_hrm_overview_screen.dart';
import '../../features/dashboard/admin/approval_queue_screen.dart';
import '../../features/dashboard/admin/payroll_screen.dart';
import '../../features/dashboard/admin/vendor_procurement_screen.dart';
import '../../features/dashboard/admin/vendor_performance_screen.dart';
import '../../features/dashboard/admin/emi_financing_screen.dart';
import '../../features/dashboard/admin/announcements_screen.dart';
import '../../features/dashboard/admin/messages_screen.dart';
import '../../features/dashboard/admin/late_fees_screen.dart';
import '../../features/dashboard/admin/offline_payment_screen.dart';
import '../../features/dashboard/admin/fee_management_screen.dart';
import '../../features/dashboard/parent/waiver_requests_screen.dart';
import '../../features/dashboard/teacher/teacher_dashboard.dart';
import '../../features/dashboard/teacher/teacher_summary_screen.dart';
import '../../features/dashboard/teacher/teacher_attendance_screen.dart';
import '../../features/dashboard/teacher/gradebook_screen.dart';
import '../../features/dashboard/teacher/lesson_resources_screen.dart';
import '../../features/dashboard/teacher/leave_requests_screen.dart';
import '../../features/dashboard/teacher/teacher_assignments_screen.dart';
import '../../features/dashboard/student/student_dashboard.dart';
import '../../features/dashboard/student/student_overview_screen.dart';
import '../../features/dashboard/student/student_schedule_screen.dart';
import '../../features/dashboard/student/student_progress_screen.dart';
import '../../features/dashboard/student/student_library_screen.dart';
import '../../features/dashboard/student/student_assignments_screen.dart';
import '../../features/dashboard/parent/parent_dashboard.dart';
import '../../features/dashboard/parent/parent_overview_screen.dart';
import '../../features/dashboard/parent/parent_fees_screen.dart';
import '../../features/dashboard/parent/parent_schedule_screen.dart';
import '../../features/dashboard/parent/parent_notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/dashboard/timetable/timetable_grid_screen.dart';
import '../../features/dashboard/omr/omr_upload_screen.dart';
import '../../features/dashboard/documents/document_review_screen.dart';
import '../../shared/widgets/role_shell.dart';

/// Every route a signed-in user can reach, as (path, builder) pairs. This is the UNION
/// of all roles' nav destinations (deduplicated — principal and admin share the
/// /admin/* operational routes). One shared StatefulShellRoute builds a branch per
/// entry here; RoleShell reads the current role from the provider and renders that
/// role's sidebar config (which may be a subset / different grouping of these same
/// branches). Route paths are preserved EXACTLY as before this refactor — no renames.
///
/// NOTE on the role/home mismatch: a logged-in principal's homeRoute is '/principal'
/// and an admin's is '/admin' — both are branches in this single shell, so the redirect
/// lands each role on its own front-page branch inside the same persistent shell.
class _RouteDef {
  const _RouteDef(this.path, this.builder);
  final String path;
  final Widget Function(BuildContext, GoRouterState) builder;
}

const _sharedRoutes = <_RouteDef>[
  // Role front pages.
  _RouteDef('/principal', _principal),
  _RouteDef('/admin', _admin),
  _RouteDef('/admin/hr-overview', _adminHrOverview),
  _RouteDef('/admin/finance-overview', _adminFinanceOverview),
  _RouteDef('/teacher', _teacher),
  _RouteDef('/student', _student),
  _RouteDef('/parent', _parent),

  // Shared operational screens (used by principal + admin, and some by teacher/student).
  _RouteDef('/admin/timetable', _timetable),
  _RouteDef('/admin/omr', _omr),
  _RouteDef('/admin/documents', _documents),
  _RouteDef('/admin/approvals', _approvals),
  _RouteDef('/admin/approvals/hr', _approvalsHr),
  _RouteDef('/admin/approvals/finance', _approvalsFinance),
  _RouteDef('/admin/payroll', _payroll),
  _RouteDef('/admin/vendors', _vendors),
  _RouteDef('/admin/vendor-performance', _vendorPerf),
  _RouteDef('/admin/emi', _emi),
  _RouteDef('/admin/leave', _leave),
  _RouteDef('/admin/announcements', _announcements),
  _RouteDef('/admin/messages', _messages),
  _RouteDef('/admin/budget', _budget),
  _RouteDef('/admin/late-fees', _lateFees),
  _RouteDef('/admin/waivers', _waivers),
  _RouteDef('/admin/fees', _feeManagement),
  _RouteDef('/admin/offline-payments', _offlinePayments),

  // Settings (all roles).
  _RouteDef('/settings', _settings),

  // Teacher-scoped.
  _RouteDef('/teacher/leave', _leave),
  _RouteDef('/teacher/assignments', _teacherAssignments),
  _RouteDef('/teacher/attendance', _teacherAttendance),
  _RouteDef('/teacher/gradebook', _gradebook),
  _RouteDef('/teacher/resources', _lessonResources),
  _RouteDef('/teacher/announcements', _announcements),
  _RouteDef('/teacher/messages', _messages),

  // Student-scoped.
  _RouteDef('/student/assignments', _studentAssignments),
  _RouteDef('/student/schedule', _studentSchedule),
  _RouteDef('/student/progress', _studentProgress),
  _RouteDef('/student/library', _studentLibrary),
  _RouteDef('/student/announcements', _announcements),
  _RouteDef('/student/messages', _messages),

  // Parent-scoped.
  _RouteDef('/parent/waivers', _waivers),
  _RouteDef('/parent/fees', _parentFees),
  _RouteDef('/parent/schedule', _parentSchedule),
  _RouteDef('/parent/notifications', _parentNotifications),
  _RouteDef('/parent/announcements', _announcements),
  _RouteDef('/parent/messages', _messages),
];

// Top-level builder functions so the const list above can reference them (const ctors
// can't reference inline closures). Keeping them tiny + colocated with the route table.
Widget _principal(_, __) => const PrincipalDashboard();
Widget _admin(_, __) => const AdminDashboard();
Widget _adminHrOverview(_, __) => const AdminHrmOverviewScreen();
Widget _adminFinanceOverview(_, __) => const AdminFinanceOverviewScreen();
Widget _teacher(_, __) => const TeacherSummaryScreen();
Widget _student(_, __) => const StudentOverviewScreen();
Widget _parent(_, __) => const ParentOverviewScreen();
Widget _timetable(_, __) => const TimetableGridScreen();
Widget _omr(_, __) => const OmrUploadScreen();
Widget _documents(_, __) => const DocumentReviewScreen();
Widget _approvals(_, __) => const ApprovalQueueScreen();
Widget _approvalsHr(_, __) => const ApprovalQueueScreen(filter: 'hr');
Widget _approvalsFinance(_, __) => const ApprovalQueueScreen(filter: 'finance');
Widget _payroll(_, __) => const PayrollScreen();
Widget _vendors(_, __) => const VendorProcurementScreen();
Widget _vendorPerf(_, __) => const VendorPerformanceScreen();
Widget _emi(_, __) => const EmiFinancingScreen();
Widget _leave(_, __) => const LeaveRequestsScreen();
Widget _announcements(_, __) => const AnnouncementsScreen();
Widget _messages(_, __) => const MessagesScreen();
Widget _budget(_, __) => const BudgetScreen();
Widget _lateFees(_, __) => const LateFeesScreen();
Widget _waivers(_, __) => const WaiverRequestsScreen();
Widget _teacherAssignments(_, __) => const TeacherAssignmentsScreen();
Widget _teacherAttendance(_, __) => const TeacherAttendanceScreen();
Widget _gradebook(_, __) => const GradebookScreen();
Widget _lessonResources(_, __) => const LessonResourcesScreen();
Widget _studentAssignments(_, __) => const StudentAssignmentsScreen();
Widget _studentSchedule(_, __) => const StudentScheduleScreen();
Widget _studentProgress(_, __) => const StudentProgressScreen();
Widget _studentLibrary(_, __) => const StudentLibraryScreen();
Widget _parentFees(_, __) => const ParentFeesScreen();
Widget _parentSchedule(_, __) => const ParentScheduleScreen();
Widget _parentNotifications(_, __) => const ParentNotificationsScreen();
Widget _feeManagement(_, __) => const FeeManagementScreen();
Widget _offlinePayments(_, __) => const OfflinePaymentScreen();
Widget _settings(_, __) => const SettingsScreen();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RiverpodRefreshStream(ref),
    redirect: (context, state) {
      final session = ref.read(currentSessionProvider);
      final loggingIn = state.matchedLocation == '/login';
      final atRoot = state.matchedLocation == '/';
      if (authState.isLoading) return atRoot ? null : '/';
      if (session == null) return loggingIn ? null : '/login';
      if (loggingIn || atRoot) {
        final role = ref.read(userRoleProvider);
        return role.homeRoute;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/unauthorized', builder: (context, state) => const UnauthorizedScreen()),
      // A single persistent shell wraps every signed-in route. RoleShell reads the current
      // role from the provider to render that role's sidebar; navigation between branches
      // happens via context.go(route) (path-based) so shared /admin/* routes work for both
      // principal and admin without registering any path twice.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            RoleShell(navigationShell: navigationShell),
        branches: [
          for (final r in _sharedRoutes)
            StatefulShellBranch(routes: [GoRoute(path: r.path, builder: r.builder)]),
        ],
      ),
    ],
  );
});

class _RiverpodRefreshStream extends ChangeNotifier {
  _RiverpodRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
