import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/background_theme_provider.dart';
import 'background_painters.dart';

/// App-wide responsive backdrop wrapper.
///
/// Dynamically renders user-selected background presets (Solid Colors, Gradients,
/// Architectural Geometric Patterns, and Minimal Vector Landscapes) across every
/// dashboard screen and user profile in the ERP.
class WarmBackdrop extends ConsumerWidget {
  const WarmBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(backgroundPresetProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Layer (Solid Color or Gradient)
        DecoratedBox(
          decoration: BoxDecoration(
            color: preset.gradient == null ? preset.baseColor : null,
            gradient: preset.gradient,
          ),
        ),

        // 2. Pattern or Vector Landscape Overlay
        if (preset.patternType != BackgroundPatternType.none)
          Positioned.fill(
            child: IgnorePointer(
              child: BackgroundPatternWidget(
                type: preset.patternType,
                accentColor: preset.accentColor,
              ),
            ),
          ),

        // 3. Main Screen Content
        child,
      ],
    );
  }
}
