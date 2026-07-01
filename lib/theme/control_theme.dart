import 'package:flutter/material.dart';

class ControlColors {
  static const deepNavy = Color(0xFF0F1B2D);
  static const charcoal = Color(0xFF1E2A3A);
  static const slate = Color(0xFF2A3A4F);
  static const teal = Color(0xFF2A9D8F);
  static const tealMuted = Color(0xFF3D8B7A);
  static const sandBeige = Color(0xFFE8DCC8);
  static const sandLight = Color(0xFFF5F0E8);
  static const offWhite = Color(0xFFFAFAF8);
  static const textPrimary = Color(0xFFF0EDE8);
  static const textSecondary = Color(0xFFB8C0CC);
  static const textMuted = Color(0xFF8A95A5);
  static const accentWarm = Color(0xFFD4A574);
  static const border = Color(0xFF3A4A5C);
  static const cardBg = Color(0xFF1A2636);
  static const warningBg = Color(0xFF2D3A2A);
}

class ControlTheme {
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: ControlColors.teal,
      secondary: ControlColors.sandBeige,
      surface: ControlColors.charcoal,
      onPrimary: Colors.white,
      onSecondary: ControlColors.deepNavy,
      onSurface: ControlColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ControlColors.deepNavy,
      cardTheme: CardThemeData(
        color: ControlColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ControlColors.border, width: 0.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ControlColors.charcoal,
        foregroundColor: ControlColors.textPrimary,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: ControlColors.border,
        thickness: 0.5,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: ControlColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ControlColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ControlColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: ControlColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: ControlColors.textSecondary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: ControlColors.textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ControlColors.teal,
          letterSpacing: 0.5,
        ),
      ),
      iconTheme: const IconThemeData(
        color: ControlColors.textSecondary,
        size: 20,
      ),
    );
  }
}
