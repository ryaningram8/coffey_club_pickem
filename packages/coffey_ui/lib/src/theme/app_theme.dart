import 'package:flutter/material.dart';

/// Material 3 theme for Coffey Club Pickem.
/// Uses a dark green seed color with sport-inspired palette.
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF1B5E20); // deep green

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
