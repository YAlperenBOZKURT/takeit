import 'package:flutter/material.dart';

/// "Terra — Organic Design": warm cream surfaces, forest-green primary, amber
/// tertiary. Typography: Plus Jakarta Sans, falling back to Inter then the
/// system sans-serif.
///
/// Colour tokens come straight from the exported Stitch design system.
const _primaryFont = 'Plus Jakarta Sans';
const _fallbackFonts = ['Inter'];

const _terraScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF4A7C59),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFC8E8D0),
  onPrimaryContainer: Color(0xFF002110),
  secondary: Color(0xFF6B6358),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFF0E8DB),
  onSecondaryContainer: Color(0xFF5E5548),
  tertiary: Color(0xFF705C30),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF8E0A8),
  onTertiaryContainer: Color(0xFF554020),
  error: Color(0xFFB83230),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD8),
  onErrorContainer: Color(0xFF690005),
  surface: Color(0xFFFAF6F0),
  onSurface: Color(0xFF2E3230),
  onSurfaceVariant: Color(0xFF4A4E4A),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF5F1EA),
  surfaceContainer: Color(0xFFF0ECE4),
  surfaceContainerHigh: Color(0xFFEAE6DE),
  surfaceContainerHighest: Color(0xFFE4E0D8),
  surfaceDim: Color(0xFFDBD7CF),
  surfaceBright: Color(0xFFFAF6F0),
  outline: Color(0xFF74796E),
  outlineVariant: Color(0xFFC4C8BC),
  inverseSurface: Color(0xFF2E3230),
  onInverseSurface: Color(0xFFF5F0E8),
  inversePrimary: Color(0xFF8ECF9E),
  surfaceTint: Color(0xFF4A7C59),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
);

/// The Terra light theme. Built once and cached: [ThemeData] doesn't override
/// `==`, so handing MaterialApp a fresh instance on every rebuild makes its
/// implicit theme-change animation think the theme changed even when nothing
/// did, which can crash mid cross-fade. A stable top-level `final` keeps the
/// same identity across the app's lifetime.
final ThemeData terraTheme = _buildTerraTheme();

ThemeData _buildTerraTheme() {
  final scheme = _terraScheme;
  const radius = 12.0;

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: _primaryFont,
    fontFamilyFallback: _fallbackFonts,
  );

  // Plus Jakarta Sans throughout: bold headlines, slightly heavier body/labels.
  final textTheme = base.textTheme
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
      .copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        displayMedium: base.textTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: _primaryFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        // `inherit: false` matches the M3 default button textStyle that the
        // other themes implicitly fall back to (they don't override it). If
        // this ever ends up `inherit: true` while another theme's button
        // style is `inherit: false`, switching between Terra and that theme
        // makes TextStyle.lerp throw ("Failed to interpolate TextStyles with
        // different inherit values") the moment a FilledButton is on screen
        // during the transition — so keep this explicit, don't rely on
        // whatever labelLarge happens to resolve to.
        textStyle: textTheme.labelLarge?.copyWith(
          fontFamily: _primaryFont,
          fontWeight: FontWeight.w700,
          inherit: false,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        backgroundColor: scheme.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        side: BorderSide(color: scheme.outlineVariant),
        // inherit: false — see filledButtonTheme above for why.
        textStyle: textTheme.labelLarge?.copyWith(
          fontFamily: _primaryFont,
          fontWeight: FontWeight.w700,
          inherit: false,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.tertiary,
      foregroundColor: scheme.onTertiary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      hintStyle: TextStyle(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.4),
      thickness: 0.5,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}
