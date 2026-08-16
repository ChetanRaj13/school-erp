import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/warm_backdrop.dart';

/// FLAT REDESIGN: this screen previously ONLY held the background-photo preset
/// picker (mountain_trail / study_hall). That feature is retired as part of the
/// flat-design migration — see warm_backdrop.dart's doc comment — so this screen is
/// rebuilt around what's actually real and functional: the signed-in account, role,
/// and sign-out. No fake toggles are added here (e.g. a "Notifications" switch that
/// doesn't persist anywhere) — every row on this screen does something real. Add
/// Notifications/Privacy rows once there's an actual preference to back them.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final role = ref.watch(userRoleProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text('ACCOUNT', style: _groupLabelStyle(context)),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: Icons.person_outline_rounded,
                            title: user?.email ?? 'Not signed in',
                            subtitle: 'Signed-in account',
                            accent: role.accentOnLight,
                          ),
                          const Divider(height: 1.5, indent: 16, endIndent: 16),
                          _SettingsRow(
                            icon: Icons.verified_user_outlined,
                            title: role.label,
                            subtitle: 'Your role',
                            accent: role.accentOnLight,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('SESSION', style: _groupLabelStyle(context)),
                    const SizedBox(height: 8),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: _SettingsRow(
                        icon: Icons.logout_rounded,
                        title: 'Log out',
                        titleColor: AppColors.error,
                        iconColor: AppColors.error,
                        onTap: () => ref.read(supabaseClientProvider).auth.signOut(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Notifications and privacy preferences will appear here once they\'re '
                      'backed by a real setting — nothing on this screen is cosmetic.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? _groupLabelStyle(BuildContext context) {
    return Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.titleColor,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = iconColor ?? accent ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10), // sm/md — a small badge, not a pill
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 14.5,
                          color: titleColor ?? AppColors.textPrimary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
