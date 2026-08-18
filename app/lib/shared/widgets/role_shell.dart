import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/admin_workspace_provider.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_role.dart';
import '../../core/router/nav_config.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// The responsive application shell wrapping every role dashboard.
///
/// On screens >= 840px, renders a persistent left sidebar with the role's
/// navigation items, school branding, and sign-out. On smaller screens, renders
/// an app bar with a hamburger-triggered drawer plus a bottom navigation bar
/// for roles with <= 5 destinations.
class RoleShell extends ConsumerWidget {
  const RoleShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _wideBreakpoint = 840.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final nav = navFor(role);
    final location = GoRouterState.of(context).matchedLocation;
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isWide) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            _Sidebar(
              nav: nav,
              role: role,
              activeRoute: location,
              onSelected: (route) => _navigateTo(context, route),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // Narrow: app bar + drawer (full sectioned list) + bottom nav for short roles
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(role.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GlassChip(
              label: role.label,
              icon: Icons.verified_user_outlined,
              color: isDark ? role.accentFill : role.accentOnLight,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () => ref.read(supabaseClientProvider).auth.signOut(),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: isDark ? const Color(0xFF0F172A) : null,
        child: _Sidebar(
          nav: nav,
          role: role,
          activeRoute: location,
          onSelected: (route) {
            Navigator.of(context).pop(); // close drawer first
            _navigateTo(context, route);
          },
          asDrawerList: true,
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: nav.flat.length <= 5
          ? NavigationBar(
              selectedIndex: _flatIndexFor(nav, location),
              indicatorColor: isDark ? role.accentFill.withValues(alpha: 0.25) : role.accentSoft,
              backgroundColor: isDark ? const Color(0xFF0F172A) : null,
              onDestinationSelected: (i) {
                final dest = nav.flat[i];
                _navigateTo(context, dest.route);
              },
              destinations: [
                for (final d in nav.flat)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon, color: isDark ? role.accentFill : role.accentOnLight),
                    label: d.label,
                  ),
              ],
            )
          : null,
    );
  }

  void _navigateTo(BuildContext context, String route) {
    context.go(route);
  }

  int _flatIndexFor(RoleNav nav, String location) {
    final i = nav.flat.indexWhere((d) => location == d.route);
    return i < 0 ? 0 : i;
  }
}

/// The wide-screen persistent sidebar.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.nav,
    required this.role,
    required this.activeRoute,
    required this.onSelected,
    this.asDrawerList = false,
  });

  final RoleNav nav;
  final UserRole role;
  final String activeRoute;
  final ValueChanged<String> onSelected;
  final bool asDrawerList;

  List<NavSection> _adminSections(AdminWorkspace ws) {
    final sections = <NavSection>[];
    for (final section in nav.sections) {
      if (section.header == null) continue;

      if (section.header == 'Operations') {
        if (ws == AdminWorkspace.finance) {
          // Remove Student Admission, OMR Attendance, and Document Review from the Finance workspace
          final financeOpsDests = section.destinations.where((d) =>
            d.route != '/admin/enrollment' &&
            d.route != '/admin/omr' &&
            d.route != '/admin/documents'
          ).toList();
          if (financeOpsDests.isNotEmpty) {
            sections.add(NavSection(header: section.header, destinations: financeOpsDests));
          }
        } else {
          sections.add(section);
        }
        continue;
      }

      if (section.header == 'HR' || section.header == 'Finance') {
        if ((ws == AdminWorkspace.hr && section.header == 'HR') ||
            (ws == AdminWorkspace.finance && section.header == 'Finance')) {
          sections.add(section);
        }
        continue;
      }

      sections.add(section);
    }

    final overviewDest = ws == AdminWorkspace.hr
        ? const NavDestination(
            icon: Icons.space_dashboard_outlined,
            label: 'HR Overview',
            route: '/admin/hr-overview',
          )
        : const NavDestination(
            icon: Icons.space_dashboard_outlined,
            label: 'Finance Overview',
            route: '/admin/finance-overview',
          );
    sections.insert(0, NavSection(destinations: [overviewDest]));

    // Always include Settings at the bottom of the Admin navigation
    sections.add(const NavSection(destinations: [
      NavDestination(
        icon: Icons.settings_outlined,
        label: 'Settings',
        route: '/settings',
      ),
    ]));

    return sections;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveSections = role == UserRole.admin
        ? _adminSections(ref.watch(adminWorkspaceProvider))
        : nav.sections;

    final items = <Widget>[];

    if (role == UserRole.admin && !asDrawerList) {
      items.add(_WorkspaceToggle(role: role));
    }

    for (final section in effectiveSections) {
      if (section.header != null) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            section.header!.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ));
      }
      for (final dest in section.destinations) {
        items.add(_NavTile(
          icon: dest.icon,
          label: dest.label,
          selected: activeRoute == dest.route,
          onTap: () => onSelected(dest.route),
          role: role,
          compact: asDrawerList,
        ));
      }
    }

    if (asDrawerList) {
      final drawerItems = <Widget>[];
      if (role == UserRole.admin) {
        drawerItems.add(_WorkspaceToggle(role: role));
      }
      drawerItems.addAll(items);

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Icon(Icons.school_rounded, color: isDark ? role.accentFill : role.accentOnLight, size: 28),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('School ERP',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                    Text(role.label,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          ...drawerItems,
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text('Sign out',
                style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
            onTap: () => ref.read(supabaseClientProvider).auth.signOut(),
          ),
        ],
      );
    }

    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : AppColors.backgroundAlt,
        border: Border(right: BorderSide(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorder, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.school_rounded, color: isDark ? role.accentFill : role.accentOnLight, size: 26),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('School ERP',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                      Text(role.label,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: items,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: InkWell(
                onTap: () => ref.read(supabaseClientProvider).auth.signOut(),
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Text('Sign out',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single sidebar navigation tile.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.role,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final UserRole role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return ListTile(
        leading: Icon(icon,
            color: selected
                ? (isDark ? role.accentFill : role.accentOnLight)
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
            size: 22),
        title: Text(label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected
                  ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
            )),
        selected: selected,
        selectedTileColor: isDark ? role.accentFill.withValues(alpha: 0.22) : role.accentSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.input)),
        onTap: onTap,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          fillColor: selected
              ? (isDark ? role.accentFill.withValues(alpha: 0.22) : role.accentSoft)
              : (isDark ? const Color(0xFF1E293B) : AppColors.glassFill),
          child: Row(
            children: [
              Icon(icon,
                  color: selected
                      ? (isDark ? role.accentFill : role.accentOnLight)
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                  size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Admin-only workspace toggle: HR / Finance.
class _WorkspaceToggle extends ConsumerWidget {
  const _WorkspaceToggle({this.role = UserRole.admin});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(adminWorkspaceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: SegmentedButton<AdminWorkspace>(
        segments: const [
          ButtonSegment(
            value: AdminWorkspace.hr,
            icon: Icon(Icons.groups_outlined, size: 18),
            label: Text('HR', style: TextStyle(fontSize: 13)),
          ),
          ButtonSegment(
            value: AdminWorkspace.finance,
            icon: Icon(Icons.account_balance_outlined, size: 18),
            label: Text('Finance', style: TextStyle(fontSize: 13)),
          ),
        ],
        selected: {current},
        onSelectionChanged: (sel) {
          final newWs = sel.first;
          ref.read(adminWorkspaceProvider.notifier).setWorkspace(newWs);
          final targetRoute = newWs == AdminWorkspace.hr
              ? '/admin/hr-overview'
              : '/admin/finance-overview';
          context.go(targetRoute);
        },
        style: SegmentedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          selectedBackgroundColor: isDark ? role.accentFill.withValues(alpha: 0.3) : role.accentSoft,
          selectedForegroundColor: isDark ? role.accentFill : role.accentOnLight,
          foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
