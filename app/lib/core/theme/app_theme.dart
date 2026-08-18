import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/user_role.dart';

/// Design tokens for the "Contra kit" visual language — bold flat color-blocking,
/// pill shapes, high contrast surfaces.
class AppColors {
  // Backgrounds
  static const background = Color(0xFFFFFFFF); // Light background
  static const backgroundAlt = Color(0xFFF5F5F5); // Light Gray
  static const backgroundDark = Color(0xFF0B0F19); // Dark background
  static const backgroundDarkAlt = Color(0xFF1E293B); // Dark surface

  // Brand
  static const primary = Color(0xFF2E5BFF); // Royal Blue
  static const primaryDark = Color(0xFF1E44D6);
  static const primaryLight = Color(0xFFC9D6FF);

  static const secondary = Color(0xFFFF6B47); // Coral/Orange

  static const textPrimary = Color(0xFF1A1A1A); // Ink (Light mode)
  static const textSecondary = Color(0xFF6B6B6B);
  static const textPrimaryDark = Color(0xFFF8FAFC); // White/Silver (Dark mode)
  static const textSecondaryDark = Color(0xFF94A3B8); // Muted slate (Dark mode)

  static const success = Color(0xFF00A99D);
  static const warning = Color(0xFFB8860B);
  static const error = Color(0xFFE0553A);

  // Card/border tokens
  static const glassFill = Color(0xFFFFFFFF);
  static const glassFillDark = Color(0xFF1E293B);
  static const glassBorder = Color(0xFFE7E7E7);
  static const glassBorderDark = Color(0xFF334155);
  static const glassShadow = Color(0x00000000);
}

class AppRadii {
  static const card = 24.0;
  static const button = 999.0;
  static const input = 16.0;
  static const pill = 999.0;
  static const chip = 999.0;
}

class AppBlur {
  static const glass = 0.0;
  static const glassStrong = 0.0;
}

/// Per-role accent color extension.
extension RoleAccent on UserRole {
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
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC700),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. COMPLETE DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData get dark {
    final baseDark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: const Color(0xFF3B82F6),
        secondary: AppColors.secondary,
        surface: AppColors.backgroundDarkAlt,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainer: const Color(0xFF1E293B),
        surfaceContainerHigh: const Color(0xFF334155),
        error: const Color(0xFFEF4444),
      ),
    );

    final darkTextTheme = GoogleFonts.interTextTheme(baseDark.textTheme);

    return baseDark.copyWith(
      textTheme: darkTextTheme.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimaryDark, letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimaryDark, letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
        titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
        bodyLarge: GoogleFonts.inter(fontSize: 17, color: AppColors.textPrimaryDark, height: 1.4, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondaryDark, height: 1.4, fontWeight: FontWeight.w500),
        bodySmall: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondaryDark, height: 1.3, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark, letterSpacing: 0.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimaryDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFC700),
          foregroundColor: const Color(0xFF1A1A1A),
          disabledBackgroundColor: const Color(0xFF334155),
          disabledForegroundColor: const Color(0xFF94A3B8),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          side: const BorderSide(color: AppColors.textPrimaryDark, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundDarkAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.glassBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.glassBorderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondaryDark),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.glassBorderDark, thickness: 1.5, space: 1.5),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.backgroundDarkAlt,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.backgroundDarkAlt,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
