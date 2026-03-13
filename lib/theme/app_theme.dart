import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design Tokens ─────────────────────────────────────────

class AppColors {
  AppColors._();

  // Core backgrounds (Pure Solid)
  static const background = Color(0xFF09090B); // Zinc 950
  static const surface = Color(0xFF18181B);    // Zinc 900
  static const surfaceLight = Color(0xFF27272A); // Zinc 800
  static const surfaceBorder = Colors.transparent; // Borderless

  // Primary accent (Indigo)
  static const primary = Color(0xFF6366F1);
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF4338CA);

  // Fuel-context accent
  static const amber = Color(0xFFF59E0B);

  // Semantic
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFF064E3B);
  static const error = Color(0xFFF43F5E);
  static const errorLight = Color(0xFF881337);
  static const info = Color(0xFF0EA5E9);
  static const infoLight = Color(0xFF0C4A6E);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFF78350F);

  static const overlay = Color(0xCC000000);

  // Text
  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textMuted = Color(0xFF71717A);

  static const meshGradient = [
    Color(0xFF6366F1),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
  ];
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 8;
  static const double lg = 8;
  static const double xl = 8;
}

class AppSpacing {
  AppSpacing._();
  static const pagePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 20);
  static const cardPadding = EdgeInsets.all(20);
}

// ── Theme ─────────────────────────────────────────────────

class AppTheme {
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      useMaterial3: true,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -1,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          );
        }),
      ),
    );
  }
}
