import 'package:flutter/material.dart';

/// UPDATED: real preset images have arrived. Each preset now carries TWO image paths
/// — desktop and mobile — since a single image can't look right at both a 16:9
/// laptop screen and a 9:16 phone screen without either losing most of its content or
/// looking stretched. WarmBackdrop picks the right one at render time based on actual
/// screen width (see warm_backdrop.dart).
///
/// Only 2 presets ship for now — a 3rd scene (lakeside town) was generated in 3
/// variations that turned out to be 3 different scenes, not one scene in two
/// orientations, so it was deliberately dropped rather than shipping a mismatched
/// desktop/mobile pair. Add it back once a real matching pair exists.
enum BackgroundPresetId { studyHall, mountainTrail }

class BackgroundPreset {
  const BackgroundPreset({
    required this.id,
    required this.label,
    required this.hillColor,
    required this.glowColor,
    required this.baseColor,
    this.imagePathDesktop,
    this.imagePathMobile,
  });

  final BackgroundPresetId id;
  final String label;

  // Still used as the procedural-painter fallback tint if an image ever fails to
  // load, and as the base for the small settings-screen color-swatch preview.
  final Color hillColor;
  final Color glowColor;
  final Color baseColor;

  final String? imagePathDesktop;
  final String? imagePathMobile;
}

const backgroundPresets = <BackgroundPreset>[
  BackgroundPreset(
    id: BackgroundPresetId.studyHall,
    label: 'Study Hall',
    hillColor: Color(0xFFC98A5E),
    glowColor: Color(0xFFF0C987),
    baseColor: Color(0xFFF6F0E8),
    imagePathDesktop: 'assets/backgrounds/study_hall_desktop.jpg',
    imagePathMobile: 'assets/backgrounds/study_hall_mobile.jpg',
  ),
  BackgroundPreset(
    id: BackgroundPresetId.mountainTrail,
    label: 'Mountain Trail',
    hillColor: Color(0xFF6E8FA3),
    glowColor: Color(0xFFB8D4E3),
    baseColor: Color(0xFFF0F4F6),
    imagePathDesktop: 'assets/backgrounds/mountain_trail_desktop.jpg',
    imagePathMobile: 'assets/backgrounds/mountain_trail_mobile.jpg',
  ),
];

BackgroundPreset presetById(BackgroundPresetId id) =>
    backgroundPresets.firstWhere((p) => p.id == id, orElse: () => backgroundPresets.first);
