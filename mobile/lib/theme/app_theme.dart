import 'package:flutter/material.dart';

/// Green, high-contrast theme matching the project plan's sample UI
/// (Section 6) — legible for outdoor daylight use, which matters more here
/// than for a typical indoor-use app.
class AppTheme {
  static const primaryGreen = Color(0xFF1B7A3D);
  static const lightGreenBg = Color(0xFFE8F5EC);
  static const highUrgency = Color(0xFFD32F2F);
  static const mediumUrgency = Color(0xFFF57C00);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
