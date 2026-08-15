import 'package:flutter/material.dart';

/// Tact dark "instrument cluster" theme.
///
/// Drops the OptiLab orange/white scheme in favor of a dark, high-contrast
/// automotive-HUD look: near-black graphite surfaces, an electric cyan
/// primary, and restrained accents.
abstract final class AppTheme {
  static const Color background = Color(0xFF0A0E14);
  static const Color surface = Color(0xFF121821);
  static const Color surfaceHigh = Color(0xFF1B2430);
  static const Color primary = Color(0xFF2FD3E8);
  static const Color primaryDim = Color(0xFF1B7F8F);
  static const Color accent = Color(0xFFF07316); // amber-orange warning accent
  static const Color onSurface = Color(0xFFE8EEF4);
  static const Color muted = Color(0xFF8A96A6);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary: const Color(0xFF001014),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceHigh,
      secondary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: surfaceHigh),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: surfaceHigh),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF001014),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(color: surfaceHigh),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        titleMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: muted),
      ),
    );
  }
}