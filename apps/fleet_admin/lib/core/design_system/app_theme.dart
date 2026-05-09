// CODE COMMENTS -------------------------------------------------------------
// Purpose: Soltech Dart source file. Comments explain the main purpose and important code blocks.
// These comments are added for review/learning and do not change app behavior.
// ---------------------------------------------------------------------------

// BEGINNER NOTES ------------------------------------------------------------
// Central theme settings for Soltech.
// Keeping colors, text styles, and UI styling here helps all screens look consistent.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

class SoltechColors {
  const SoltechColors._();

  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color green = Color(0xFF16A34A);
  static const Color blue = Color(0xFF2563EB);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFDC2626);
}

class SoltechTheme {
  const SoltechTheme._();

  static ThemeData light() {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SoltechColors.green,
        primary: SoltechColors.green,
        surface: SoltechColors.surface,
      ),
      scaffoldBackgroundColor: SoltechColors.canvas,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: SoltechColors.surface,
        foregroundColor: SoltechColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SoltechColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoltechColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoltechColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoltechColors.green, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SoltechColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SoltechColors.ink,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
