import 'package:flutter/material.dart';

/// Authentic Italian editorial typography pairing:
/// - **Bodoni Moda** (`600`–`800`, italic `700`) — Parma Didone display serif for headings, KPIs & prices.
/// - **EB Garamond** (`400`–`700`, italic `400`) — Venetian Renaissance humanist serif for all UI & body text.
/// - **Italiana** (`400`) — Italian fashion-editorial display typeface for the PassItOn logotype.
abstract final class AppTypography {
  static const String uiFont = 'EBGaramond';
  static const String displayFont = 'BodoniModa';
  static const String brandFont = 'Italiana';

  /// Ensures currency symbols like Taka (`৳`, U+09F3) fall back cleanly.
  static const List<String> fallback = [
    'Noto Sans Bengali',
    'Noto Sans',
    'Roboto',
    'sans-serif',
  ];

  static TextTheme buildTextTheme(TextTheme base, {required bool isDark}) {
    final primary = isDark ? Colors.white : const Color(0xFF252832);
    final secondary = isDark ? const Color(0xFFA7AEBE) : const Color(0xFF687082);

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
        color: primary,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: primary,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: primary,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: primary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 16.5,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 16.5,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static TextStyle brand({
    double size = 24,
    Color? color,
    double letterSpacing = 0.4,
  }) =>
      TextStyle(
        fontFamily: brandFont,
        fontFamilyFallback: fallback,
        fontSize: size + 2,
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
        color: color,
      );

  static TextStyle display({
    double size = 28,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.35,
    double? height,
  }) =>
      TextStyle(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
        height: height,
      );

  static TextStyle price({
    double size = 18,
    FontWeight weight = FontWeight.w700,
    Color? color,
    TextDecoration? decoration,
  }) =>
      TextStyle(
        fontFamily: displayFont,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.2,
        color: color,
        decoration: decoration,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle eyebrow({
    double size = 10,
    Color? color,
    double letterSpacing = 0.9,
  }) =>
      TextStyle(
        fontFamily: uiFont,
        fontFamilyFallback: fallback,
        fontSize: size + 1,
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
        color: color,
      );
}
