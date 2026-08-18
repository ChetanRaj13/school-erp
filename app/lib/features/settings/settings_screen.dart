import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/background_theme_provider.dart';
import '../../shared/widgets/background_painters.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/warm_backdrop.dart';

/// Settings screen available across all user profiles (Principal, Admin, Teacher, Student, Parent).
///
/// Features:
/// 1. Comprehensive Wallpaper & Background Customization with Category Filters:
///    - Solid Colors
///    - Modern Gradients
///    - Modern Dot Matrix
///    - Minimal Vector Landscapes
/// 2. Account Details & Session Management.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  BackgroundCategory _selectedCategory = BackgroundCategory.all;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final role = ref.watch(userRoleProvider);
    final activePreset = ref.watch(backgroundPresetProvider);

    final filteredPresets = _selectedCategory == BackgroundCategory.all
        ? BackgroundPresets.all
        : BackgroundPresets.all.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WarmBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Settings & Appearance',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: role.accentSoft,
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              border: Border.all(color: role.accentOnLight.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              role.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: role.accentOnLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Customize your workspace background and manage account preferences.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ═════════════════════════════════════════════════════════
                    // 1. BACKGROUND WALLPAPER CUSTOMIZER
                    // ═════════════════════════════════════════════════════════
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('WORKSPACE BACKGROUND', style: _groupLabelStyle(context)),
                        if (activePreset.id != BackgroundPresets.defaultPreset.id)
                          InkWell(
                            onTap: () {
                              ref.read(backgroundPresetProvider.notifier).state = BackgroundPresets.defaultPreset;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Background reset to Studio White default.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                'Reset to Default',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E5BFF),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Category Filter Pills
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: BackgroundCategory.values.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final cat = BackgroundCategory.values[i];
                          final isCatActive = cat == _selectedCategory;

                          return InkWell(
                            onTap: () => setState(() => _selectedCategory = cat),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCatActive ? role.accentFill : Colors.white,
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                                border: Border.all(
                                  color: isCatActive ? role.accentFill : AppColors.glassBorder,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isCatActive ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid of Presets
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 720;
                        final crossAxisCount = isWide ? 4 : (constraints.maxWidth >= 480 ? 3 : 2);

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredPresets.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: isWide ? 1.45 : 1.15,
                          ),
                          itemBuilder: (context, idx) {
                            final preset = filteredPresets[idx];
                            final isSelected = preset.id == activePreset.id;

                            return _buildPresetCard(context, preset, isSelected, role.accentFill);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // ═════════════════════════════════════════════════════════
                    // 2. ACCOUNT & PROFILE
                    // ═════════════════════════════════════════════════════════
                    Text('ACCOUNT PROFILE', style: _groupLabelStyle(context)),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: Icons.person_outline_rounded,
                            title: user?.email ?? 'Not signed in',
                            subtitle: 'Signed-in account identity',
                            accent: role.accentOnLight,
                          ),
                          const Divider(height: 1.5, indent: 16, endIndent: 16),
                          _SettingsRow(
                            icon: Icons.verified_user_outlined,
                            title: role.label,
                            subtitle: 'Role permission level',
                            accent: role.accentOnLight,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ═════════════════════════════════════════════════════════
                    // 3. SESSION & SECURITY
                    // ═════════════════════════════════════════════════════════
                    Text('SESSION', style: _groupLabelStyle(context)),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: _SettingsRow(
                        icon: Icons.logout_rounded,
                        title: 'Log out',
                        subtitle: 'Sign out from this terminal securely',
                        titleColor: AppColors.error,
                        iconColor: AppColors.error,
                        onTap: () => ref.read(supabaseClientProvider).auth.signOut(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetCard(BuildContext context, BackgroundPreset preset, bool isSelected, Color roleAccent) {
    final borderWidth = isSelected ? 2.5 : 1.0;
    return InkWell(
      onTap: () {
        ref.read(backgroundPresetProvider.notifier).state = preset;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied "${preset.name}" background across your workspace.'),
            duration: const Duration(seconds: 2),
            backgroundColor: roleAccent,
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isSelected ? roleAccent : AppColors.glassBorder,
            width: borderWidth,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: roleAccent.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card - borderWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Preview Thumbnail
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Base color or gradient
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: preset.gradient == null ? preset.baseColor : null,
                        gradient: preset.gradient,
                      ),
                    ),

                  // Pattern overlay in thumbnail
                  if (preset.patternType != BackgroundPatternType.none)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: BackgroundPatternWidget(
                          type: preset.patternType,
                          accentColor: preset.accentColor,
                        ),
                      ),
                    ),

                  // Active Badge
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleAccent,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Active', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Card Footer Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          preset.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          preset.category.label,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.textSecondary,
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
                borderRadius: BorderRadius.circular(10),
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
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}
