import 'package:flutter/material.dart';

/// Plain Material 3 fallback theme (teal seed), used for [AppThemeMode.light]
/// and [AppThemeMode.dark]. Built once and cached — see `terra_theme.dart`
/// for why a stable instance matters.
final ThemeData classicLightTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  useMaterial3: true,
  brightness: Brightness.light,
);

final ThemeData classicDarkTheme = ThemeData(
  colorSchemeSeed: Colors.teal,
  useMaterial3: true,
  brightness: Brightness.dark,
);
