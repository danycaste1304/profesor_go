import 'package:flutter/material.dart';

import '../core/models/rarity.dart';
import '../core/widgets/pixel_icon.dart';
import '../core/widgets/pixel_icons.dart';

/// Bright outdoor palette with the crisp frames of a handheld adventure.
abstract final class AppColors {
  static const background = Color(0xFFF0F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFE5F4F4);
  static const border = Color(0xFFD1E3E8);
  static const shadow = Color(0x330A3F58);
  static const accent = Color(0xFFFFCE3A);
  static const accentText = Color(0xFF986400);
  static const accentAlt = Color(0xFF087C9C);
  static const danger = Color(0xFFD94B5B);
  static const dangerFill = Color(0xFFAF3044);
  static const success = Color(0xFF148567);
  static const text = Color(0xFF17304A);
  static const textMuted = Color(0xFF607A8E);
  static const onAccent = Color(0xFF17304A);

  static const rarityCommon = Color(0xFF607A8E);
  static const rarityRare = Color(0xFF2477C8);
  static const rarityEpic = Color(0xFF8B50C6);
  static const rarityLegendary = Color(0xFFB87912);
}

abstract final class AppTheme {
  /// Body font: paragraphs and every header below the page title.
  /// VT323 (license in `assets/fonts/OFL-VT323.txt`).
  static const bodyFontFamily = 'VT323';

  /// Pixel font: page titles (h1) and button labels. Silkscreen (license in
  /// `assets/fonts/OFL-Silkscreen.txt`) is wide and uppercase-only; sizes in
  /// multiples of 8 keep its pixel grid crisp.
  static const displayFontFamily = 'VT323';

  static const fontFamilyFallback = <String>[
    'SF Pro Text',
    'Arial',
    'sans-serif',
  ];

  /// Minimum touch target for primary actions.
  static const double minButtonHeight = 56;
  static const double borderWidth = 2;
  static const double radius = 5;

  static Color rarityColor(Rarity rarity) => switch (rarity) {
    Rarity.common => AppColors.rarityCommon,
    Rarity.rare => AppColors.rarityRare,
    Rarity.epic => AppColors.rarityEpic,
    Rarity.legendary => AppColors.rarityLegendary,
  };

  /// Icon that accompanies the rarity color (never color-only).
  static PixelIconData rarityIcon(Rarity rarity) => switch (rarity) {
    Rarity.common => PixelIcons.rarityCommon,
    Rarity.rare => PixelIcons.rarityRare,
    Rarity.epic => PixelIcons.rarityEpic,
    Rarity.legendary => PixelIcons.rarityLegendary,
  };

  /// Material's default tracking (0.1 to 0.5 px) widens the pixel fonts, so
  /// every style of the text theme is flattened to 0.
  static TextTheme _flat(TextTheme t) => t.copyWith(
    displayLarge: t.displayLarge?.copyWith(letterSpacing: 0),
    displayMedium: t.displayMedium?.copyWith(letterSpacing: 0),
    displaySmall: t.displaySmall?.copyWith(letterSpacing: 0),
    headlineLarge: t.headlineLarge?.copyWith(letterSpacing: 0),
    headlineMedium: t.headlineMedium?.copyWith(letterSpacing: 0),
    headlineSmall: t.headlineSmall?.copyWith(letterSpacing: 0),
    titleLarge: t.titleLarge?.copyWith(letterSpacing: 0),
    titleMedium: t.titleMedium?.copyWith(letterSpacing: 0),
    titleSmall: t.titleSmall?.copyWith(letterSpacing: 0),
    bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0),
    bodyMedium: t.bodyMedium?.copyWith(letterSpacing: 0),
    bodySmall: t.bodySmall?.copyWith(letterSpacing: 0),
    labelLarge: t.labelLarge?.copyWith(letterSpacing: 0),
    labelMedium: t.labelMedium?.copyWith(letterSpacing: 0),
    labelSmall: t.labelSmall?.copyWith(letterSpacing: 0),
  );

  static TextStyle? _display(TextStyle? base, double size) => base?.copyWith(
    fontFamily: displayFontFamily,
    fontWeight: FontWeight.w400,
    fontSize: size,
    letterSpacing: 0,
  );

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accentAlt,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceAlt,
      outline: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: bodyFontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = _flat(
      base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
        fontFamily: bodyFontFamily,
        fontFamilyFallback: fontFamilyFallback,
      ),
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        // h1 and button labels: pixel font.
        headlineLarge: _display(textTheme.headlineLarge, 40),
        headlineMedium: _display(textTheme.headlineMedium, 24),
        titleLarge: _display(textTheme.titleLarge, 30),
        labelLarge: _display(textTheme.labelLarge, 22),
        // Other headers and paragraphs: body font.
        titleMedium: textTheme.titleMedium?.copyWith(fontSize: 20),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 22, height: 1.1),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 22, height: 1),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        // Tint shown when content scrolls under the bar (M3 default is the
        // yellow `primary`); a darker blue from the palette instead.
        surfaceTintColor: AppColors.accentAlt,
        scrolledUnderElevation: 11,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: displayFontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 22,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          color: AppColors.text,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          side: BorderSide(color: AppColors.border, width: borderWidth),
        ),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: TextStyle(color: AppColors.textMuted),
        hintStyle: TextStyle(color: AppColors.textMuted),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: AppColors.accentAlt, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          borderSide: BorderSide(color: AppColors.danger, width: 3),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(minButtonHeight),
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          textStyle: const TextStyle(
            fontFamily: displayFontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentAlt,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: displayFontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            fontSize: 20,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: TextStyle(
          color: AppColors.text,
          fontFamily: bodyFontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          side: BorderSide(color: AppColors.border, width: borderWidth),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 2,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.accentAlt,
        textColor: AppColors.text,
      ),
      iconTheme: const IconThemeData(color: AppColors.text),
    );
  }

  /// Kept for existing callers and widget tests during the visual transition.
  static ThemeData dark() => light();
}
