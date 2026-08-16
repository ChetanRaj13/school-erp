import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/user_role.dart';

/// Design tokens for the new "Contra kit" visual language — bold flat color-blocking,
/// pill shapes, no gradients or drop shadows. Source of truth for the palette/shape
/// values is docs/design.md + docs/contra_design_language.md; every constant here
/// should trace back to a value in that doc.
///
/// IMPORTANT: every token name below (AppColors.x / AppRadii.x / AppBlur.x) is kept
/// identical to the previous "nature matte glass" theme on purpose — 49 files use
/// GlassCard, 17 use GlassChip, 8 use StatCard, and none of them need to change for
/// this migration. Only the values change here, plus the two widget files
/// (glass_card.dart, stat_card.dart) that consume them. Retuning this one file
/// re-colors/re-styles the whole app without touching individual screens.
class AppColors {
  // Backgrounds
  static const background = Color(0xFFFFFFFF); // White — was cream/sage F3F6F0
  static const backgroundAlt = Color(0xFFF5F5F5); // Light Gray — subtle bg / dividers

  // Brand
  static const primary = Color(0xFF2E5BFF); // Royal Blue — brand color, links, trust
  static const primaryDark = Color(0xFF1E44D6);
  static const primaryLight = Color(0xFFC9D6FF); // light tint, used for selected-nav fill

  static const secondary = Color(0xFFFF6B47); // Coral/Orange — secondary actions, tags

  static const textPrimary = Color(0xFF1A1A1A); // Ink
  static const textSecondary = Color(0xFF6B6B6B);

  static const success = Color(0xFF00A99D); // Teal/Mint, deepened slightly from the raw
  // #00D4AA extraction value for AA-safe use as text/icon color on white — see
  // RoleAccent.accentOnLight below for the same pattern applied per-role.
  static const warning = Color(0xFFB8860B); // Deepened Yellow, same AA-contrast reason —
  // raw #FFC700 fails contrast for text/icon-sized use on a white background.
  static const error = Color(0xFFE0553A); // Deepened Coral, AA-safe on white.

  // Card/border/shadow tokens — repurposed for the flat system. GlassCard/GlassChip
  // consume these directly, so this is the one place to retune the default card look.
  static const glassFill = Color(0xFFFFFFFF); // flat card fill (was translucent warm-white)
  static const glassBorder = Color(0xFFE7E7E7); // flat card hairline border (was frosted edge)
  static const glassShadow = Color(0x00000000); // fully transparent — the flat system
  // uses NO drop shadows anywhere; zeroing this here means any lingering BoxShadow
  // usage becomes invisible without needing to touch each of the 49 call sites.
}

class AppRadii {
  static const card = 24.0; // lg
  static const button = 999.0; // pill — buttons are fully rounded in this system
  static const input = 16.0; // md
  static const pill = 999.0;
  static const chip = 999.0; // pill — tags/chips are fully rounded in this system
}

/// Kept only for compile-safety with any lingering reference — the flat design system
/// uses no blur/glass effect anywhere. Both values are zeroed so BackdropFilter calls
/// (if any remain) become harmless no-ops rather than needing to be hunted down.
class AppBlur {
  static const glass = 0.0;
  static const glassStrong = 0.0;
}

/// Per-role accent color — the system's wayfinding mechanism (see docs/design.md
/// section 2). Each role gets exactly one signature color, applied only to that
/// role's app bar / active nav state / primary highlight — never to every element.
extension RoleAccent on UserRole {
  /// The role's true, vivid brand color. Use as a FILL — hero panels, active tab
  /// background, anywhere a light foreground sits on top of it. NOT for text/icon
  /// color directly on a white background — use [accentOnLight] for that.
  Color get accentFill {
    switch (this) {
      case UserRole.admin:
        return const Color(0xFF2E5BFF); // Royal Blue
      case UserRole.principal:
        return const Color(0xFFFF6B47); // Coral
      case UserRole.teacher:
        return const Color(0xFF00D4AA); // Teal/Mint
      case UserRole.student:
        return const Color(0xFFFFC700); // Primary Yellow
      case UserRole.parent:
        return const Color(0xFFFF6B9D); // Hot Pink
      case UserRole.unknown:
        return AppColors.primary;
    }
  }

  /// Contrast-safe version of the role accent for text/icon/border use directly on a
  /// white or light-gray background. Golden yellow especially needs this — the raw
  /// #FFC700 fails AA contrast for text/icon-sized elements on white.
  Color get accentOnLight {
    switch (this) {
      case UserRole.admin:
        return const Color(0xFF2E5BFF);
      case UserRole.principal:
        return const Color(0xFFE0553A);
      case UserRole.teacher:
        return const Color(0xFF00877D);
      case UserRole.student:
        return const Color(0xFFB8860B);
      case UserRole.parent:
        return const Color(0xFFE0568C);
      case UserRole.unknown:
        return AppColors.primary;
    }
  }

  /// A light tint of the accent, for chip/badge backgrounds sitting behind
  /// [accentOnLight] text or icons.
  Color get accentSoft {
    switch (this) {
      case UserRole.admin:
        return const Color(0xFFEAF0FF);
      case UserRole.principal:
        return const Color(0xFFFFE7E0);
      case UserRole.teacher:
        return const Color(0xFFDFFAF3);
      case UserRole.student:
        return const Color(0xFFFFF3CC);
      case UserRole.parent:
        return const Color(0xFFFFE6EF);
      case UserRole.unknown:
        return AppColors.primaryLight;
    }
  }
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
    );

    // google_fonts is already a dependency (used by cinematic_hero_header.dart), so
    // this doesn't add anything new to pubspec.yaml. Poppins carries headings, Inter
    // carries body/label text — matches docs/design.md's typography section.
    final interTextTheme = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: interTextTheme.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 17, color: AppColors.textPrimary, height: 1.4, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary, height: 1.4, fontWeight: FontWeight.w500),
        bodySmall: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.3, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
      // This single block restyles every plain ElevatedButton in the app (login's
      // "Sign in" button included) to the flat pill-button system with zero changes
      // needed at the call site.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC700), // Primary Yellow — the system's universal CTA color
          foregroundColor: AppColors.textPrimary,
          disabledBackgroundColor: AppColors.backgroundAlt,
          disabledForegroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.textPrimary, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.glassBorder, thickness: 1.5, space: 1.5),
    );
  }

  static ThemeData get dark => light;
}
