import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Refetch's colour tokens, copied from refetch.io (`src/styles/app.css`,
/// documented in the web repo's DESIGN.md). Where each value came from is
/// recorded in docs/BRANDING.md.
@immutable
class RefetchColors extends ThemeExtension<RefetchColors> {
  const RefetchColors({
    required this.brand,
    required this.brandText,
    required this.brandTint,
    required this.logoWordmark,
    required this.bg,
    required this.surface,
    required this.surfaceSecondary,
    required this.label,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.labelQuaternary,
    required this.separator,
    required this.fill,
    required this.up,
    required this.upTint,
    required this.down,
    required this.downTint,
  });

  /// The logo mark, primary buttons, selection. Same in both themes.
  final Color brand;

  /// Links and accents on surfaces; lifted in dark mode for contrast.
  final Color brandText;
  final Color brandTint;
  final Color logoWordmark;
  final Color bg;
  final Color surface;
  final Color surfaceSecondary;
  final Color label;
  final Color labelSecondary;
  final Color labelTertiary;
  final Color labelQuaternary;
  final Color separator;
  final Color fill;
  final Color up;
  final Color upTint;
  final Color down;
  final Color downTint;

  static const light = RefetchColors(
    brand: Color(0xFF4E1CB3),
    brandText: Color(0xFF4E1CB3),
    brandTint: Color(0xFFF3EEFF),
    logoWordmark: Color(0xFF1D1D1F),
    bg: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceSecondary: Color(0xFFF5F5F7),
    label: Color(0xFF1D1D1F),
    labelSecondary: Color(0xFF6E6E73),
    labelTertiary: Color(0xFF86868B),
    labelQuaternary: Color(0xFFAEAEB2),
    separator: Color(0x14000000),
    fill: Color(0x1F767680),
    up: Color(0xFF16A34A),
    upTint: Color(0xFFE9F8EF),
    down: Color(0xFFDC2626),
    downTint: Color(0xFFFDEDED),
  );

  static const dark = RefetchColors(
    brand: Color(0xFF4E1CB3),
    brandText: Color(0xFF9B7CF6),
    brandTint: Color(0x524E1CB3),
    logoWordmark: Color(0xFFFFFFFF),
    bg: Color(0xFF0E0D13),
    surface: Color(0xFF17161E),
    surfaceSecondary: Color(0xFF1F1E28),
    label: Color(0xFFF3F2F7),
    labelSecondary: Color(0xFFA9A7B5),
    labelTertiary: Color(0xFF7A788A),
    labelQuaternary: Color(0xFF4F4D5E),
    separator: Color(0x12FFFFFF),
    fill: Color(0x12FFFFFF),
    up: Color(0xFF30D158),
    upTint: Color(0x2430D158),
    down: Color(0xFFFF453A),
    downTint: Color(0x24FF453A),
  );

  @override
  RefetchColors copyWith() => this;

  @override
  RefetchColors lerp(RefetchColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return RefetchColors(
      brand: c(brand, other.brand),
      brandText: c(brandText, other.brandText),
      brandTint: c(brandTint, other.brandTint),
      logoWordmark: c(logoWordmark, other.logoWordmark),
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceSecondary: c(surfaceSecondary, other.surfaceSecondary),
      label: c(label, other.label),
      labelSecondary: c(labelSecondary, other.labelSecondary),
      labelTertiary: c(labelTertiary, other.labelTertiary),
      labelQuaternary: c(labelQuaternary, other.labelQuaternary),
      separator: c(separator, other.separator),
      fill: c(fill, other.fill),
      up: c(up, other.up),
      upTint: c(upTint, other.upTint),
      down: c(down, other.down),
      downTint: c(downTint, other.downTint),
    );
  }
}

extension RefetchTheme on BuildContext {
  RefetchColors get colors => Theme.of(this).extension<RefetchColors>()!;
}

/// Light and dark themes in the refetch.io look: grey grouped canvas, white
/// rounded cards, the Refetch purple for the one primary action, Poppins for
/// titles and Inter (system font on Apple platforms) for everything else.
class AppTheme {
  AppTheme._();

  /// Card radius (`rounded-card`) and control radius (`rounded-control`).
  static const double cardRadius = 20;
  static const double controlRadius = 12;

  static const display = 'Poppins';

  /// Apple platforms use the system font (SF Pro), as the site does via
  /// `-apple-system`; everywhere else, bundled Inter.
  static String? get _body => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => null,
    _ => 'Inter',
  };

  static ThemeData get light => _build(Brightness.light, RefetchColors.light);
  static ThemeData get dark => _build(Brightness.dark, RefetchColors.dark);

  static ThemeData _build(Brightness brightness, RefetchColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brandText,
      onPrimary: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF0E0D13),
      primaryContainer: c.brandTint,
      onPrimaryContainer: c.brandText,
      secondary: c.labelSecondary,
      onSecondary: c.surface,
      error: c.down,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.label,
      onSurfaceVariant: c.labelSecondary,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bg,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceSecondary,
      surfaceContainerHighest: c.surfaceSecondary,
      outline: c.labelQuaternary,
      outlineVariant: c.separator,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _body,
    );
    final text = _textTheme(base.textTheme, c);

    // One filled action per view, in the logo purple with white text, in
    // both themes (`brand` / `on-brand`).
    final filled = FilledButton.styleFrom(
      backgroundColor: c.brand,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      textStyle: text.labelLarge,
      minimumSize: const Size(64, 44),
    );

    return base.copyWith(
      textTheme: text,
      extensions: [c],
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerTheme: DividerThemeData(
        color: c.separator,
        thickness: 0.5,
        space: 0.5,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.label,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.label,
        unselectedLabelColor: c.labelTertiary,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        indicatorColor: c.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStatePropertyAll(c.fill),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(style: filled),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.label,
          backgroundColor: c.fill,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
          minimumSize: const Size(64, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brandText,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: c.brandText, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: c.down),
        ),
        labelStyle: TextStyle(color: c.labelSecondary),
        hintStyle: TextStyle(color: c.labelTertiary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.up : c.fill,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.surface,
          backgroundColor: c.fill,
          side: BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.labelSecondary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(color: c.labelSecondary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brandText),
    );
  }

  /// The site's type scale (DESIGN.md › Typography): titles in Poppins,
  /// the rest in the body font.
  static TextTheme _textTheme(TextTheme base, RefetchColors c) {
    TextStyle title(
      double size,
      FontWeight weight,
      double height, [
      double tracking = 0,
    ]) => TextStyle(
      fontFamily: display,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: tracking,
      color: c.label,
    );
    TextStyle body(
      double size,
      FontWeight weight,
      double height, [
      Color? color,
    ]) => TextStyle(
      // Set explicitly: these styles replace the theme's defaults, so they
      // would otherwise lose ThemeData.fontFamily and fall back to Roboto.
      fontFamily: _body,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
      color: color ?? c.label,
    );

    return base.copyWith(
      displaySmall: title(34, FontWeight.w700, 1.2, -0.4), // large-title
      headlineMedium: title(28, FontWeight.w700, 1.2, -0.3), // title-1
      headlineSmall: title(22, FontWeight.w700, 1.25, -0.2), // title-2
      titleLarge: title(20, FontWeight.w600, 1.3), // title-3
      titleMedium: body(17, FontWeight.w600, 1.3), // headline
      titleSmall: body(15, FontWeight.w600, 1.3),
      bodyLarge: body(17, FontWeight.w400, 1.45), // body
      bodyMedium: body(15, FontWeight.w400, 1.45), // subhead
      bodySmall: body(13, FontWeight.w400, 1.35, c.labelSecondary), // footnote
      labelLarge: body(15, FontWeight.w600, 1.2),
      labelMedium: body(13, FontWeight.w600, 1.2),
      labelSmall: body(12, FontWeight.w500, 1.2, c.labelTertiary), // caption-1
    );
  }
}
