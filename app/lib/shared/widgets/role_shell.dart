import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            child: GlassChip(label: role.label, icon: Icons.verified_user_outlined),
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
              onDestinationSelected: (i) {
                final dest = nav.flat[i];
                _navigateTo(context, dest.route);
              },
              destinations: [
                for (final d in nav.flat)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.icon),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <Widget>[];

    for (final section in nav.sections) {
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
          compact: asDrawerList,
        ));
      }
    }

    if (asDrawerList) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
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
          ...items,
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
                  const Icon(Icons.school_rounded, color: AppColors.primary, size: 26),
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

/// A single sidebar navigation tile. Selected state uses a glass fill + primary icon so
/// the active screen is obvious without a hard material highlight.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ListTile(
        leading: Icon(icon,
            color: selected ? AppColors.primary : AppColors.textSecondary, size: 22),
        title: Text(label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            )),
        selected: selected,
        selectedTileColor: AppColors.primaryLight.withValues(alpha: 0.18),
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
              ? AppColors.primaryLight.withValues(alpha: 0.28)
              : AppColors.glassFill,
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? AppColors.primary : AppColors.textSecondary, size: 20),
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
