import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/admin_workspace_provider.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/user_role.dart';
import '../../core/router/nav_config.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// The persistent navigation chrome shared by every authenticated role screen.
///
/// Replaces the old "one long scrolling page per role" pattern: instead of a dashboard
/// page cramming ~14 Quick Link tiles into a single scroll view, the role's navigation
/// destinations live here (sidebar on wide screens, drawer + bottom-nav on narrow), and
/// each destination renders inside this shell via a go_router StatefulShellRoute.
///
/// Navigation is PATH-BASED (context.go(route)), not branch-index-based. This matters
/// because the operational /admin/* routes are shared by both principal and admin — a
/// single shared shell builds one branch per route path, while each role's sidebar is a
/// differently-grouped VIEW over those same branches. Matching by current location (not
/// shell.currentIndex) keeps the active highlight correct regardless of which role's
/// grouping the sidebar uses.
///
/// The shell does NOT wrap children in its own backdrop — each route screen keeps its
/// own Scaffold + WarmBackdrop (nested Scaffolds are valid). The shell only owns the
/// sidebar/drawer/bottom-nav + a mobile app bar, so leaf screens keep their existing
/// look minus the now-redundant sign-out button (it lives here instead).
class RoleShell extends ConsumerWidget {
  const RoleShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  // Wide-screen breakpoint for the persistent sidebar. Below this, the sidebar becomes
  // a Drawer and a bottom NavigationBar appears under the content.
  static const _wideBreakpoint = 840.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final nav = navFor(role);
    final location = GoRouterState.of(context).matchedLocation;
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.background,
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

    // Narrow: app bar + drawer (full sectioned list) + a bottom nav for the short
    // roles (<=5 destinations). Long roles (principal/admin: 14+) use the drawer only.
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(role.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GlassChip(
              label: role.label,
              icon: Icons.verified_user_outlined,
              color: role.accentOnLight,
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
              indicatorColor: role.accentSoft,
              onDestinationSelected: (i) {
                final dest = nav.flat[i];
                _navigateTo(context, dest.route);
              },
              destinations: [
                for (final d in nav.flat)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon, color: role.accentOnLight),
                    label: d.label,
                  ),
              ],
            )
          : null,
    );
  }

  void _navigateTo(BuildContext context, String route) {
    // context.go within a StatefulShellRoute switches the active branch to whichever
    // branch holds `route` while keeping the shell (and other branches' state) alive.
    context.go(route);
  }

  /// The active destination's index within the role's flat nav list, or 0 if the
  /// current location isn't one of this role's destinations (e.g. deep-linked). Used
  /// only for the mobile bottom-nav highlight.
  int _flatIndexFor(RoleNav nav, String location) {
    final i = nav.flat.indexWhere((d) => location == d.route);
    return i < 0 ? 0 : i;
  }
}

/// The wide-screen persistent sidebar: a glass panel with a role header, sectioned
/// navigation items, and a sign-out at the bottom. `asDrawerList` renders the same
/// content as a plain scrollable list (no glass card chrome) for use inside a Drawer.
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

  /// Filters sections for admin workspace: HR shows HR-only items, Finance
  /// shows Finance-only items. Operations is always included. The Overview
  /// section (first section, no header) is replaced with the workspace-
  /// specific overview route.
  List<NavSection> _adminSections(AdminWorkspace ws) {
    final sections = <NavSection>[];
    for (final section in nav.sections) {
      // Skip the headerless Overview section — we replace it below.
      if (section.header == null) continue;

      if (section.header == 'Operations') {
        // Operations always visible in both workspaces.
        sections.add(section);
        continue;
      }

      if (section.header == 'HR' || section.header == 'Finance') {
        // Include the workspace-specific section.
        if ((ws == AdminWorkspace.hr && section.header == 'HR') ||
            (ws == AdminWorkspace.finance && section.header == 'Finance')) {
          sections.add(section);
        }
        continue;
      }

      // Communication / other sections: always visible.
      sections.add(section);
    }

    // Prepend the workspace-specific overview.
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

    return sections;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For admin role, filter sections by workspace; otherwise use all sections.
    final effectiveSections = role == UserRole.admin
        ? _adminSections(ref.watch(adminWorkspaceProvider))
        : nav.sections;

    final items = <Widget>[];

    // Admin workspace toggle (only in sidebar, not drawer list — drawer gets it too).
    if (role == UserRole.admin && !asDrawerList) {
      items.add(_WorkspaceToggle(role: role));
    }

    for (final section in effectiveSections) {
      if (section.header != null) {
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            section.header!.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
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
      // Build drawer items with workspace toggle for admin.
      final drawerItems = <Widget>[];
      if (role == UserRole.admin) {
        drawerItems.add(_WorkspaceToggle(role: role));
      }
      drawerItems.addAll(items);

      return ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: role.accentFill),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(role.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ...drawerItems,
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('Sign out'),
            onTap: () => ref.read(supabaseClientProvider).auth.signOut(),
          ),
        ],
      );
    }

    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: AppColors.backgroundAlt,
        border: Border(right: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.school_rounded, color: role.accentOnLight, size: 26),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('School ERP',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text(role.label,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
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
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                      SizedBox(width: 12),
                      Text('Sign out',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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

/// A single sidebar navigation tile. Selected state uses a role-accent soft fill + role accent icon.
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
    if (compact) {
      return ListTile(
        leading: Icon(icon,
            color: selected ? role.accentOnLight : AppColors.textSecondary, size: 22),
        title: Text(label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            )),
        selected: selected,
        selectedTileColor: role.accentSoft,
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
              ? role.accentSoft
              : AppColors.glassFill,
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? role.accentOnLight : AppColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
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

/// Admin-only workspace toggle: HR / Finance. Rendered at the top of the admin
/// sidebar to switch between the two workspaces.
class _WorkspaceToggle extends ConsumerWidget {
  const _WorkspaceToggle({this.role = UserRole.admin});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(adminWorkspaceProvider);
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
          selectedBackgroundColor: role.accentSoft,
          selectedForegroundColor: role.accentOnLight,
          foregroundColor: AppColors.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
