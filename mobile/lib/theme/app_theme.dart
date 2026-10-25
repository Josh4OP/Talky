import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema único de la aplicación. Todos los colores, tipografías y formas viven
/// aquí para que las pantallas no inventen estilos sueltos.
abstract final class AppTheme {
  static const _font = 'PlusJakartaSans';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.ocean,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.ocean,
      onPrimary: Colors.white,
      primaryContainer: AppColors.blueSoft,
      onPrimaryContainer: AppColors.oceanDark,
      secondary: AppColors.turquoise,
      onSecondary: const Color(0xFF00352F),
      secondaryContainer: AppColors.turquoiseSoft,
      onSecondaryContainer: const Color(0xFF064F48),
      tertiary: AppColors.coral,
      onTertiary: const Color(0xFF562000),
      tertiaryContainer: AppColors.coralSoft,
      onTertiaryContainer: const Color(0xFF7A2E09),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerSoft,
      onErrorContainer: const Color(0xFF7A1F1F),
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkSoft,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.blueMist,
      surfaceContainer: AppColors.canvas,
      surfaceContainerHigh: AppColors.surfaceSunken,
      surfaceContainerHighest: const Color(0xFFE8EEF6),
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _font,
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );

    final text = base.textTheme
        .apply(fontFamily: _font, bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: _font,
            fontSize: 58,
            height: 1.04,
            fontWeight: FontWeight.w800,
            letterSpacing: -2.2,
            color: AppColors.ink,
          ),
          displayMedium: const TextStyle(
            fontFamily: _font,
            fontSize: 44,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.6,
            color: AppColors.ink,
          ),
          displaySmall: const TextStyle(
            fontFamily: _font,
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            color: AppColors.ink,
          ),
          headlineLarge: const TextStyle(
            fontFamily: _font,
            fontSize: 30,
            height: 1.16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: AppColors.ink,
          ),
          headlineMedium: const TextStyle(
            fontFamily: _font,
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: AppColors.ink,
          ),
          headlineSmall: const TextStyle(
            fontFamily: _font,
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.ink,
          ),
          titleLarge: const TextStyle(
            fontFamily: _font,
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          titleMedium: const TextStyle(
            fontFamily: _font,
            fontSize: 15.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          titleSmall: const TextStyle(
            fontFamily: _font,
            fontSize: 13.5,
            height: 1.35,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          bodyLarge: const TextStyle(
            fontFamily: _font,
            fontSize: 16,
            height: 1.55,
            fontWeight: FontWeight.w400,
            color: AppColors.inkSoft,
          ),
          bodyMedium: const TextStyle(
            fontFamily: _font,
            fontSize: 14.5,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: AppColors.inkSoft,
          ),
          bodySmall: const TextStyle(
            fontFamily: _font,
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
          labelLarge: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: AppColors.ink,
          ),
          labelMedium: const TextStyle(
            fontFamily: _font,
            fontSize: 12.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          labelSmall: const TextStyle(
            fontFamily: _font,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        );

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: const IconThemeData(color: AppColors.inkSoft, size: 22),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: AppColors.ocean,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderStrong,
          disabledForegroundColor: Colors.white70,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          foregroundColor: AppColors.ocean,
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ocean,
          textStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.inkSoft,
          highlightColor: AppColors.blueSoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.blueMist,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: AppColors.inkMuted,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ocean, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.blueSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _font,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.ocean
                : AppColors.inkMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? AppColors.ocean
                : AppColors.inkMuted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.blueSoft,
        selectedIconTheme: const IconThemeData(color: AppColors.ocean, size: 23),
        unselectedIconTheme: const IconThemeData(color: AppColors.inkMuted, size: 23),
        selectedLabelTextStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ocean,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.inkMuted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.blueMist,
        selectedColor: AppColors.blueSoft,
        surfaceTintColor: Colors.transparent,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.oceanDeep,
        contentTextStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.oceanDeep,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontFamily: _font,
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ocean,
        linearTrackColor: AppColors.blueSoft,
        circularTrackColor: AppColors.blueSoft,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.turquoise
              : AppColors.borderStrong,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.turquoise
              : AppColors.borderStrong,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkSoft,
        textColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
