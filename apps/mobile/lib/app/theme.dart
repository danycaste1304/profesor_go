import 'package:flutter/material.dart';

import '../core/models/rarity.dart';

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
  static const fontFamily = 'Roboto';
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
  static IconData rarityIcon(Rarity rarity) => switch (rarity) {
    Rarity.common => Icons.circle_outlined,
    Rarity.rare => Icons.star_border,
    Rarity.epic => Icons.star,
    Rarity.legendary => Icons.auto_awesome,
  };

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
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.35),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.35),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 0.2,
          fontSize: 16,
        ),
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 20,
          fontWeight: FontWeight.w900,
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
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentAlt,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: TextStyle(
          color: AppColors.text,
          fontFamily: fontFamily,
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
