import 'package:flutter/material.dart';
import 'package:whisk/ui/core/whisk_colors.dart';

ThemeData buildWhiskTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kAccentBlue,
      brightness: Brightness.dark,
      surface: kPanel,
    ),
    scaffoldBackgroundColor: kAppBlack,
    fontFamily: 'Segoe UI',
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: kTextPrimary,
      displayColor: kTextPrimary,
    ),
  );
}
