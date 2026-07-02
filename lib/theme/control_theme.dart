import 'package:flutter/material.dart';

class ControlColors {
  static const background = Color(0xFFF4F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const deepNavy = Color(0xFF0F172A);
  static const charcoal = Color(0xFFFFFFFF);
  static const slate = Color(0xFFF1F5F9);
  static const teal = Color(0xFF0D9488);
  static const tealMuted = Color(0xFF14B8A6);
  static const tealSoft = Color(0xFFCCFBF1);
  static const sandBeige = Color(0xFF0369A1);
  static const sandLight = Color(0xFFE0F2FE);
  static const offWhite = Color(0xFFFAFCFE);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const accentWarm = Color(0xFFF59E0B);
  static const accentRose = Color(0xFFE11D48);
  static const accentGreen = Color(0xFF059669);
  static const border = Color(0xFFE2E8F0);
  static const cardBg = Color(0xFFFFFFFF);
  static const warningBg = Color(0xFFFFFBEB);
  static const heroGradientStart = Color(0xFFECFEFF);
  static const heroGradientEnd = Color(0xFFF0F9FF);
}

class ControlTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: ControlColors.teal,
      secondary: ControlColors.sandBeige,
      surface: ControlColors.surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: ControlColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ControlColors.background,
      cardTheme: CardThemeData(
        color: ControlColors.cardBg,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ControlColors.border, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ControlColors.surface,
        foregroundColor: ControlColors.textPrimary,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: ControlColors.border,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ControlColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: ControlColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ControlColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ControlColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ControlColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: ControlColors.textSecondary,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: ControlColors.textSecondary,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ControlColors.teal,
          letterSpacing: 0.3,
        ),
      ),
      iconTheme: const IconThemeData(
        color: ControlColors.textSecondary,
        size: 20,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
