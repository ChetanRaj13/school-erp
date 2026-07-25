import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/background_preset_provider.dart';
import '../../core/theme/background_presets.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/warm_backdrop.dart';

/// UPDATED: the preset preview now shows a real thumbnail of the actual mobile image
/// (via ClipRRect + Image.asset) instead of a plain color-gradient swatch, now that
/// real preset art exists.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(backgroundPresetProvider);

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
                    Text('Background', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Choose the background used throughout the app.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ...backgroundPresets.map((preset) {
                      final isSelected = preset.id == selected;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => ref.read(backgroundPresetProvider.notifier).select(preset.id),
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          child: GlassCard(
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: preset.imagePathMobile != null
                                      ? Image.asset(
                                          preset.imagePathMobile!,
                                          width: 56, height: 56, fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _fallbackSwatch(preset),
                                        )
                                      : _fallbackSwatch(preset),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(preset.label, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: AppColors.primary)
                                else
                                  const Icon(Icons.circle_outlined, color: AppColors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Text(
                      'More backgrounds can be added later — this list will grow as new presets are provided.',
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

  Widget _fallbackSwatch(BackgroundPreset preset) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [preset.baseColor, preset.hillColor.withValues(alpha: 0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
