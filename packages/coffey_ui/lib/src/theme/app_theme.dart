import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 theme for Coffey Club Pickem, built on Iowa State
/// University's brand colors: Cardinal and Gold.
class AppTheme {
  AppTheme._();

  /// ISU Cardinal — injected explicitly as `primary`. Letting
  /// `ColorScheme.fromSeed` derive `primary` from this seed instead (as a
  /// tone-mapped, algorithmically desaturated version of it) reads
  /// noticeably duller than the true brand red, so it's hand-set here, the
  /// same way `secondary`/Gold already was.
  static const Color _cardinal = Color(0xFFC8102E);

  /// ISU Gold — injected explicitly as `secondary`. A single-seed palette
  /// derived from Cardinal alone would produce a muted brownish secondary
  /// rather than true gold, so gold and its container tones are hand-set.
  static const Color _gold = Color(0xFFF1BE48);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _cardinal,
      brightness: Brightness.light,
    ).copyWith(
      primary: _cardinal,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFDAD6),
      onPrimaryContainer: const Color(0xFF410002),
      secondary: _gold,
      onSecondary: const Color(0xFF3F2E00),
      secondaryContainer: const Color(0xFFFFE08C),
      onSecondaryContainer: const Color(0xFF261A00),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(textTheme: GoogleFonts.jostTextTheme(base.textTheme));
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _cardinal,
      brightness: Brightness.dark,
    ).copyWith(
      // Lighter than the light theme's primary — `primary` also serves as
      // text/icon color on dark surfaces (outlined buttons, text buttons),
      // where the true dark Cardinal red wouldn't have enough contrast.
      primary: const Color(0xFFFFB4AB),
      onPrimary: const Color(0xFF690005),
      primaryContainer: const Color(0xFF93000A),
      onPrimaryContainer: const Color(0xFFFFDAD6),
      // Slightly muted vs. the light theme — a fully saturated gold reads
      // harsh against dark surfaces.
      secondary: const Color(0xFFE7C06C),
      onSecondary: const Color(0xFF3F2E00),
      secondaryContainer: const Color(0xFF5C4400),
      onSecondaryContainer: const Color(0xFFFFE08C),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(textTheme: GoogleFonts.jostTextTheme(base.textTheme));
  }
}
