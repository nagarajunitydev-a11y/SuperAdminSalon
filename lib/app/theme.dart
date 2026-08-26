import 'package:flutter/material.dart';
import '../core/state/value_controller.dart';

/// Light/dark mode, persisted only for the session. Defaults to the platform
/// preference so the console matches the operator's OS setting on first load.
final themeModeProvider = valueProvider<ThemeMode>(ThemeMode.system);

const _seed = Color(0xFF6D4AFF);

/// Categorical palette for charts. Chosen to stay distinguishable in both
/// themes and to remain separable for the most common colour-vision
/// deficiencies — hue alone is never the only carrier of meaning in the charts
/// below (each series is also labelled).
const chartPalette = <Color>[
  Color(0xFF6D4AFF),
  Color(0xFF00B8A9),
  Color(0xFFF6A609),
  Color(0xFFEF476F),
  Color(0xFF3D8BFD),
  Color(0xFF8FBF3F),
];

ThemeData _base(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF0E1117) : const Color(0xFFF6F7FB),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF161B25) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.60)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: isDark ? const Color(0xFF0E1117) : const Color(0xFFF1F3F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
  );
}

ThemeData get lightTheme => _base(Brightness.light);
ThemeData get darkTheme => _base(Brightness.dark);
