import 'package:flutter/material.dart';

/// Design tokens for the "nature matte glass" visual language — sage/mist palette with
/// an illustrated nature backdrop. GlassCard, GlassChip, and every screen using them
/// automatically inherit any change made here — retuning this one file re-colors/
/// re-styles the whole app without touching individual screens.
class AppColors {
  static const background = Color(0xFFF3F6F0);
  static const backgroundAlt = Color(0xFFE7EFE2);

  static const primary = Color(0xFF6B8F5E);
  static const primaryDark = Color(0xFF547347);
  static const primaryLight = Color(0xFFA8C39B);

  static const secondary = Color(0xFFE8B892);

  static const textPrimary = Color(0xFF2B332A);
  static const textSecondary = Color(0xFF5A6354); // darkened for better contrast on glass

  static const success = Color(0xFF5FA05A);
  static const warning = Color(0xFFD9A441);
  static const error = Color(0xFFC1553F);

  // UPDATED: bumped from 50% to 65% opacity per user feedback — less see-through,
  // more readable text against the frosted-glass background. Still shows the
  // backdrop enough to keep the glass effect visible.
  static const glassFill = Color(0xA6FAF9F5); // 65% opacity warm off-white
  static const glassBorder = Color(0x33FFFFFF); // slightly more visible edge, needed
  // now that the fill itself is less opaque, so cards still read clearly as cards
  static const glassShadow = Color(0x1A2B332A);
}

class AppRadii {
  static const card = 28.0;
  static const button = 20.0;
  static const input = 18.0;
  static const pill = 999.0;
  static const chip = 14.0;
}

class AppBlur {
  // Increased slightly from before (14/22) — at 50% opacity, a bit more blur keeps
  // the background readable-but-soft (real frosted glass) instead of looking like a
  // sharp, distracting view straight through to the backdrop.
  static const glass = 18.0;
  static const glassStrong = 26.0;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.background,
        error: AppColors.error,
      ),
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3,
        ),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: const TextStyle(fontSize: 17, color: AppColors.textPrimary, height: 1.4),
        bodyMedium: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
        bodySmall: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  static ThemeData get dark => light;
}
