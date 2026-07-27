import 'package:flutter/material.dart';

import '../auth/user_role.dart';

/// A single sidebar/drawer navigation destination, bound to a route path. One object
/// powers BOTH the router (which branch it lives in) and the sidebar (what icon/label
/// to show + where to navigate when tapped) — so a screen can never drift out of sync
/// between "reachable via sidebar" and "registered as a route."
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;

  /// Absolute route path, e.g. '/admin/payroll'. Must match a registered GoRoute.
  final String route;
}

/// A role's full navigation set: an ordered list of destinations grouped (for display
/// as sectioned headers in the sidebar) into sections. The first destination of the
/// first section is the role's home/front page.
class RoleNav {
  const RoleNav({required this.sections});

  final List<NavSection> sections;

  /// Flat list of every destination, in display order. Used by the router to build
  /// branches and by the sidebar's bottom-nav (mobile) variant.
  List<NavDestination> get flat =>
      sections.expand((s) => s.destinations).toList(growable: false);
}

class NavSection {
  const NavSection({this.header, required this.destinations});

  /// Optional section header label (e.g. "Finance"). null = unlabeled group.
  final String? header;
  final List<NavDestination> destinations;
}

/// The single source of truth for what each role can navigate to. The router builds
/// one branch per destination here; the sidebar reads the same list to render items.
/// Routes MUST stay in sync with app_router.dart — preserved exactly as they were
/// before this refactor (no renames).
RoleNav navFor(UserRole role) {
  switch (role) {
    case UserRole.principal:
      // Principal's front page (Overview) is the dashboard itself at /principal.
      // The ~14 quick links that used to be a scrolling list are now sidebar items.
      return const RoleNav(sections: [
        NavSection(destinations: [
          NavDestination(
              icon: Icons.space_dashboard_outlined,
              label: 'Overview',
              route: '/principal'),
        ]),
        NavSection(header: 'Finance', destinations: [
          NavDestination(
              icon: Icons.receipt_long_outlined,
              label: 'Fee Management',
              route: '/admin/fees'),
          NavDestination(
              icon: Icons.payments_outlined,
              label: 'Offline Payments',
              route: '/admin/offline-payments'),
          NavDestination(
              icon: Icons.pending_actions_outlined,
              label: 'Approval Queue',
              route: '/admin/approvals'),
          NavDestination(
              icon: Icons.payments_outlined, label: 'Payroll', route: '/admin/payroll'),
          NavDestination(
              icon: Icons.storefront_outlined,
              label: 'Vendors & Procurement',
              route: '/admin/vendors'),
          NavDestination(
              icon: Icons.bar_chart_outlined,
              label: 'Vendor Performance',
              route: '/admin/vendor-performance'),
          NavDestination(
              icon: Icons.credit_score_outlined,
              label: 'EMI / Fee Financing',
              route: '/admin/emi'),
          NavDestination(
              icon: Icons.pie_chart_outline, label: 'Budget', route: '/admin/budget'),
          NavDestination(
              icon: Icons.timer_outlined, label: 'Late Fees', route: '/admin/late-fees'),
          NavDestination(
              icon: Icons.volunteer_activism_outlined,
              label: 'Scholarships & Waivers',
              route: '/admin/waivers'),
        ]),
        NavSection(header: 'Operations', destinations: [
          NavDestination(
              icon: Icons.event_busy_outlined,
              label: 'Leave Requests',
              route: '/admin/leave'),
          NavDestination(
              icon: Icons.calendar_view_week_outlined,
              label: 'Weekly Timetable',
              route: '/admin/timetable'),
          NavDestination(
              icon: Icons.document_scanner_outlined,
              label: 'OMR Attendance',
              route: '/admin/omr'),
          NavDestination(
              icon: Icons.fact_check_outlined,
              label: 'Document Review',
              route: '/admin/documents'),
        ]),
        NavSection(header: 'Communication', destinations: [
          NavDestination(
              icon: Icons.campaign_outlined,
              label: 'Announcements',
              route: '/admin/announcements'),
          NavDestination(
              icon: Icons.mail_outline, label: 'Messages', route: '/admin/messages'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
        ]),
      ]);

    case UserRole.admin:
      // Admin's sidebar is split into HR / Finance workspaces via a SegmentedButton
      // toggle in the sidebar. The headerless Overview section is replaced at render
      // time by the workspace-specific overview (HR or Finance). The sidebar's
      // _adminSections method filters sections by the active workspace — here we
      // declare ALL sections and let the sidebar pick which to show.
      //
      // HR workspace: Payroll, HR Approvals (payroll-only filter of Approval Queue),
      //   Leave Requests.
      // Finance workspace: Fee Management, Offline Payments, Finance Approvals
      //   (POs + vendor payments only), Vendors & Procurement, Vendor Performance,
      //   EMI/Financing, Budget, Late Fees, Scholarships & Waivers.
      // Shared Operations: Announcements, Messages, OMR Attendance, Document Review,
      //   Weekly Timetable — always visible in both workspaces.
      return const RoleNav(sections: [
        // Headerless — replaced by _adminSections with workspace-specific overview.
        NavSection(destinations: [
          NavDestination(
              icon: Icons.space_dashboard_outlined, label: 'Overview', route: '/admin'),
        ]),
        NavSection(header: 'HR', destinations: [
          NavDestination(
              icon: Icons.payments_outlined, label: 'Payroll', route: '/admin/payroll'),
          NavDestination(
              icon: Icons.pending_actions_outlined,
              label: 'HR Approvals',
              route: '/admin/approvals/hr'),
          NavDestination(
              icon: Icons.event_busy_outlined,
              label: 'Leave Requests',
              route: '/admin/leave'),
        ]),
        NavSection(header: 'Finance', destinations: [
          NavDestination(
              icon: Icons.receipt_long_outlined,
              label: 'Fee Management',
              route: '/admin/fees'),
          NavDestination(
              icon: Icons.payments_outlined,
              label: 'Offline Payments',
              route: '/admin/offline-payments'),
          NavDestination(
              icon: Icons.pending_actions_outlined,
              label: 'Finance Approvals',
              route: '/admin/approvals/finance'),
          NavDestination(
              icon: Icons.storefront_outlined,
              label: 'Vendors & Procurement',
              route: '/admin/vendors'),
          NavDestination(
              icon: Icons.bar_chart_outlined,
              label: 'Vendor Performance',
              route: '/admin/vendor-performance'),
          NavDestination(
              icon: Icons.credit_score_outlined,
              label: 'EMI / Fee Financing',
              route: '/admin/emi'),
          NavDestination(
              icon: Icons.pie_chart_outline, label: 'Budget', route: '/admin/budget'),
          NavDestination(
              icon: Icons.timer_outlined, label: 'Late Fees', route: '/admin/late-fees'),
          NavDestination(
              icon: Icons.volunteer_activism_outlined,
              label: 'Scholarships & Waivers',
              route: '/admin/waivers'),
        ]),
        NavSection(header: 'Operations', destinations: [
          NavDestination(
              icon: Icons.campaign_outlined,
              label: 'Announcements',
              route: '/admin/announcements'),
          NavDestination(
              icon: Icons.mail_outline, label: 'Messages', route: '/admin/messages'),
          NavDestination(
              icon: Icons.document_scanner_outlined,
              label: 'OMR Attendance',
              route: '/admin/omr'),
          NavDestination(
              icon: Icons.fact_check_outlined,
              label: 'Document Review',
              route: '/admin/documents'),
          NavDestination(
              icon: Icons.calendar_view_week_outlined,
              label: 'Weekly Timetable',
              route: '/admin/timetable'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
        ]),
      ]);

    case UserRole.teacher:
      // Front page = teacher summary at /teacher (today's overview, not just schedule).
      return const RoleNav(sections: [
        NavSection(destinations: [
          NavDestination(
              icon: Icons.space_dashboard_outlined, label: 'Summary', route: '/teacher'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.fact_check_outlined,
              label: 'Attendance',
              route: '/teacher/attendance'),
          NavDestination(
              icon: Icons.grading_outlined,
              label: 'Gradebook',
              route: '/teacher/gradebook'),
          NavDestination(
              icon: Icons.assignment_outlined,
              label: 'Assignments',
              route: '/teacher/assignments'),
          NavDestination(
              icon: Icons.menu_book_outlined,
              label: 'Lesson Resources',
              route: '/teacher/resources'),
          NavDestination(
              icon: Icons.event_busy_outlined,
              label: 'Leave Requests',
              route: '/teacher/leave'),
          NavDestination(
              icon: Icons.campaign_outlined,
              label: 'Announcements',
              route: '/teacher/announcements'),
          NavDestination(
              icon: Icons.mail_outline, label: 'Messages', route: '/teacher/messages'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
        ]),
      ]);

    case UserRole.student:
      // Front page = student overview at /student (multi-card summary dashboard).
      return const RoleNav(sections: [
        NavSection(destinations: [
          NavDestination(
              icon: Icons.space_dashboard_outlined, label: 'Overview', route: '/student'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.schedule_outlined,
              label: 'Schedule',
              route: '/student/schedule'),
          NavDestination(
              icon: Icons.trending_up_outlined,
              label: 'Progress',
              route: '/student/progress'),
          NavDestination(
              icon: Icons.menu_book_outlined,
              label: 'Library',
              route: '/student/library'),
          NavDestination(
              icon: Icons.assignment_outlined,
              label: 'Assignments',
              route: '/student/assignments'),
          NavDestination(
              icon: Icons.campaign_outlined,
              label: 'Announcements',
              route: '/student/announcements'),
          NavDestination(
              icon: Icons.mail_outline, label: 'Messages', route: '/student/messages'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
        ]),
      ]);

    case UserRole.parent:
      // Front page = parent overview at /parent (child-centric summary dashboard).
      return const RoleNav(sections: [
        NavSection(destinations: [
          NavDestination(
              icon: Icons.space_dashboard_outlined, label: 'Overview', route: '/parent'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.receipt_long_outlined,
              label: 'Fees',
              route: '/parent/fees'),
          NavDestination(
              icon: Icons.schedule_outlined,
              label: 'Schedule',
              route: '/parent/schedule'),
          NavDestination(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              route: '/parent/notifications'),
          NavDestination(
              icon: Icons.campaign_outlined,
              label: 'Announcements',
              route: '/parent/announcements'),
          NavDestination(
              icon: Icons.mail_outline,
              label: 'Messages',
              route: '/parent/messages'),
          NavDestination(
              icon: Icons.volunteer_activism_outlined,
              label: 'Scholarships & Waivers',
              route: '/parent/waivers'),
        ]),
        NavSection(destinations: [
          NavDestination(
              icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
        ]),
      ]);

    case UserRole.unknown:
      return const RoleNav(sections: []);
  }
}
