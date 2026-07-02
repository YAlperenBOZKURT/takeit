import 'package:flutter/material.dart';

/// Warm-dark companion to the Terra light theme, used for [AppThemeMode.dark]
/// and [AppThemeMode.modern]/system-dark. Built once and cached — see
/// `terra_theme.dart` for why a stable instance matters.
final ThemeData modernDarkTheme = _buildModernDarkTheme();

ThemeData _buildModernDarkTheme() {
  const bg = Color(0xFF181C21);
  const surface = Color(0xFF1C2229);
  const primary = Color(0xFFE67E22);
  const textPrimary = Color(0xFFFFFFFF);
  const textSecondary = Color(0xFFC6C7C9);
  const textMuted = Color(0xFF3B424C);

  const surfaceHigh = Color(0xFF242A32);
  const border = Color(0xFF2A3038);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: textPrimary,
      primaryContainer: Color(0xFFBF6516),
      onPrimaryContainer: textPrimary,
      secondary: primary,
      onSecondary: textPrimary,
      secondaryContainer: surfaceHigh,
      onSecondaryContainer: textPrimary,
      tertiary: primary,
      tertiaryContainer: surfaceHigh,
      onTertiaryContainer: textPrimary,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: bg,
      surfaceContainerLow: Color(0xFF1A1F25),
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: border,
      outline: border,
      outlineVariant: Color(0xFF22272E),
      error: Color(0xFFEF4444),
      onError: textPrimary,
      errorContainer: Color(0xFF3B1515),
      onErrorContainer: Color(0xFFFCA5A5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border, width: 0.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: surface),
    dividerTheme: const DividerThemeData(color: border, thickness: 0.5),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: primary,
      labelStyle: const TextStyle(color: textSecondary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: textPrimary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceHigh,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg,
      hintStyle: const TextStyle(color: textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textPrimary,
      iconColor: textMuted,
    ),
    iconTheme: const IconThemeData(color: textMuted),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: textPrimary,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
  );
}
