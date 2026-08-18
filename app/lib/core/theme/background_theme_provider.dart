import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BackgroundCategory {
  all(label: 'All Styles'),
  solid(label: 'Solid Colors'),
  gradient(label: 'Gradients'),
  pattern(label: 'Patterns'),
  landscape(label: 'Minimal Landscapes');

  const BackgroundCategory({required this.label});
  final String label;
}

enum BackgroundPatternType {
  none,
  dotMatrix,
  alpinePeaks,
  desertDunes,
  forestLake,
}

class BackgroundPreset {
  const BackgroundPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.baseColor,
    this.gradient,
    this.patternType = BackgroundPatternType.none,
    this.accentColor,
    required this.previewColors,
  });

  final String id;
  final String name;
  final BackgroundCategory category;
  final String description;
  final Color baseColor;
  final Gradient? gradient;
  final BackgroundPatternType patternType;
  final Color? accentColor;
  final List<Color> previewColors;
}

/// Curated library of light backgrounds across Solid Colors, Gradients, Dot Matrix, and Minimal Landscapes.
class BackgroundPresets {
  static const List<BackgroundPreset> all = [
    // ═════════════════════════════════════════════════════════════════════════
    // 1. SOLID COLORS
    // ═════════════════════════════════════════════════════════════════════════
    BackgroundPreset(
      id: 'solid_pure_white',
      name: 'Studio White',
      category: BackgroundCategory.solid,
      description: 'Crisp, high-contrast studio white canvas',
      baseColor: Color(0xFFFFFFFF),
      previewColors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
    ),
    BackgroundPreset(
      id: 'solid_warm_cream',
      name: 'Warm Canvas',
      category: BackgroundCategory.solid,
      description: 'Warm cream matte surface for reduced eye strain',
      baseColor: Color(0xFFFDFBF7),
      previewColors: [Color(0xFFFDFBF7), Color(0xFFF5EFE6)],
    ),
    BackgroundPreset(
      id: 'solid_soft_slate',
      name: 'Soft Slate',
      category: BackgroundCategory.solid,
      description: 'Subtle slate gray foundation',
      baseColor: Color(0xFFF1F5F9),
      previewColors: [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    ),
    BackgroundPreset(
      id: 'solid_mint_tint',
      name: 'Mint Serenity',
      category: BackgroundCategory.solid,
      description: 'Gentle refreshing pastel mint wash',
      baseColor: Color(0xFFF0FDF4),
      previewColors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
    ),
    BackgroundPreset(
      id: 'solid_ice_blue',
      name: 'Ice Blue',
      category: BackgroundCategory.solid,
      description: 'Calm Scandinavian winter ice tint',
      baseColor: Color(0xFFF0F7FF),
      previewColors: [Color(0xFFF0F7FF), Color(0xFFDBEAFE)],
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 2. SMOOTH MODERN GRADIENTS
    // ═════════════════════════════════════════════════════════════════════════
    BackgroundPreset(
      id: 'grad_aurora',
      name: 'Aurora Glow',
      category: BackgroundCategory.gradient,
      description: 'Dreamy atmospheric blend of soft cyan, lavender & rose',
      baseColor: Color(0xFFF0F9FF),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE), Color(0xFFFFE4E6)],
      ),
      previewColors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE), Color(0xFFFFE4E6)],
    ),
    BackgroundPreset(
      id: 'grad_sunset',
      name: 'Sunset Horizon',
      category: BackgroundCategory.gradient,
      description: 'Warm golden amber fading into coral and peach',
      baseColor: Color(0xFFFFFBEB),
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFFEF3C7), Color(0xFFFFEDD5), Color(0xFFFFE4E6)],
      ),
      previewColors: [Color(0xFFFEF3C7), Color(0xFFFFEDD5), Color(0xFFFFE4E6)],
    ),
    BackgroundPreset(
      id: 'grad_ocean_breeze',
      name: 'Ocean Breeze',
      category: BackgroundCategory.gradient,
      description: 'Fresh sky blue transitioning into coastal mint',
      baseColor: Color(0xFFF0FDFA),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE0F2FE), Color(0xFFCCFBF1), Color(0xFFF0FDF4)],
      ),
      previewColors: [Color(0xFFE0F2FE), Color(0xFFCCFBF1), Color(0xFFF0FDF4)],
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 3. PATTERNS
    // ═════════════════════════════════════════════════════════════════════════
    BackgroundPreset(
      id: 'pattern_dot_matrix',
      name: 'Modern Dot Matrix',
      category: BackgroundCategory.pattern,
      description: 'Minimalist Scandinavian precision dot matrix',
      baseColor: Color(0xFFFAFAFA),
      patternType: BackgroundPatternType.dotMatrix,
      accentColor: Color(0xFFCBD5E1),
      previewColors: [Color(0xFFFAFAFA), Color(0xFFE5E7EB), Color(0xFF6B7280)],
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 4. MINIMAL VECTOR LANDSCAPES
    // ═════════════════════════════════════════════════════════════════════════
    BackgroundPreset(
      id: 'landscape_alpine_peaks',
      name: 'Alpine Mist Peaks',
      category: BackgroundCategory.landscape,
      description: 'Minimalist vector mountain ridge with atmospheric morning fog',
      baseColor: Color(0xFFF0FDF4),
      patternType: BackgroundPatternType.alpinePeaks,
      previewColors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD), Color(0xFF0284C7)],
    ),
    BackgroundPreset(
      id: 'landscape_golden_dunes',
      name: 'Golden Dune Mirage',
      category: BackgroundCategory.landscape,
      description: 'Flowing minimalist sand dune contours with sunset gradients',
      baseColor: Color(0xFFFFFBEB),
      patternType: BackgroundPatternType.desertDunes,
      previewColors: [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFF59E0B)],
    ),
    BackgroundPreset(
      id: 'landscape_nordic_lake',
      name: 'Nordic Lake & Pines',
      category: BackgroundCategory.landscape,
      description: 'Serene evergreen tree silhouettes over calm reflective waters',
      baseColor: Color(0xFFF0FDF4),
      patternType: BackgroundPatternType.forestLake,
      previewColors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0), Color(0xFF059669)],
    ),
  ];

  static BackgroundPreset get defaultPreset => all.first;

  static BackgroundPreset findById(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => defaultPreset);
  }
}

/// Provider for active Background Preset
final backgroundPresetProvider = StateProvider<BackgroundPreset>((ref) => BackgroundPresets.defaultPreset);
