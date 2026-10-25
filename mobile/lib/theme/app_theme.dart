import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Estilos de texto de la guía de marca (estilos de texto de Figma con el mismo nombre).
/// Nunito para títulos y cifras, Nunito Sans para texto. Las fuentes son variables,
/// así que el peso se fija también con `wght`.
abstract final class AppText {
  static const _title = 'Nunito';
  static const _body = 'NunitoSans';

  static TextStyle _style(String family, double size, double height, FontWeight weight, {double spacing = 0}) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        letterSpacing: spacing,
        color: AppColors.ink,
      );

  static final display = _style(_title, 32, 38, FontWeight.w900);
  static final title = _style(_title, 24, 30, FontWeight.w800);
  static final heading = _style(_title, 18, 24, FontWeight.w800);
  static final metric = _style(_title, 28, 32, FontWeight.w900);
  static final body = _style(_body, 16, 24, FontWeight.w400);
  static final bodyStrong = _style(_body, 16, 24, FontWeight.w700);
  static final caption = _style(_body, 14, 20, FontWeight.w600);
  static final overline = _style(_body, 14, 18, FontWeight.w700, spacing: 1.1);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.action,
    onPrimary: AppColors.onAction,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'NunitoSans',
    textTheme: TextTheme(
      displaySmall: AppText.display,
      headlineSmall: AppText.title,
      titleMedium: AppText.heading,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      labelLarge: AppText.bodyStrong,
      bodySmall: AppText.caption,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppText.heading,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.action,
        foregroundColor: AppColors.onAction,
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: AppText.bodyStrong,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.action, textStyle: AppText.bodyStrong),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.tint20,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppText.caption.copyWith(
          color: states.contains(WidgetState.selected) ? AppColors.action : AppColors.inkMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.action : AppColors.inkMuted),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.body.copyWith(color: AppColors.surface),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
