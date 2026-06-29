import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

ThemeData buildWhiskTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccentBlue,
      brightness: Brightness.dark,
      surface: kGlassBase,
      surfaceContainer: kGlassBase.withValues(alpha: 0.8),
      onSurface: kTextPrimary,
      outline: kBorder,
    ),
    scaffoldBackgroundColor: kAppBlack,
    fontFamily: 'Figtree',
    fontFamilyFallback: const ['Segoe UI', 'sans-serif'],
    cardTheme: CardThemeData(
      color: kGlassBase.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: kBorder,
      thickness: 1,
      space: 1,
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: kTextPrimary,
      displayColor: kTextPrimary,
      fontFamily: 'Figtree',
    ),
  );
}
