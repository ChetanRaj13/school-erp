import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// FLAT REDESIGN: the photo-backdrop system (background_presets.dart,
/// background_preset_provider.dart, the mountain_trail/study_hall JPGs) is retired by
/// this migration — the new design system uses solid, saturated color-blocked
/// backgrounds, not photography (see docs/design.md section 2: "Backgrounds are
/// solid, saturated colors — never gradients [or photos]").
///
/// Kept as the same widget name/constructor (`WarmBackdrop({required child})`) on
/// purpose, so none of the screens that wrap themselves in WarmBackdrop (login,
/// settings, and others) need to change their import or usage — only what happens
/// inside build() changes, same pattern as glass_card.dart and stat_card.dart.
///
/// HONEST FOLLOW-UP NEEDED: background_presets.dart and background_preset_provider.dart
/// still exist in the repo but are no longer read by anything after this change, and
/// settings_screen.dart's preset picker (see the accompanying rebuild of that file) no
/// longer offers it. That's dead code now, not deleted here since this migration
/// intentionally only touches the shared-widget layer — flag it in docs/tech_debt.md
/// and remove in a follow-up cleanup pass.
class WarmBackdrop extends StatelessWidget {
  const WarmBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: child,
    );
  }
}
