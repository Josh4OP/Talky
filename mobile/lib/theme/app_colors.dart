import 'package:flutter/painting.dart';

/// Colores de marca. Los nombres coinciden con las variables "Talky" de Figma
/// (`color/brand/primary` -> [primary], `color/action/primary` -> [action]).
abstract final class AppColors {
  static const primary = Color(0xFF4FBEFF);
  static const tint80 = Color(0xFF74CCFF);
  static const tint60 = Color(0xFF99D9FF);
  static const tint40 = Color(0xFFBFE6FF);
  static const tint20 = Color(0xFFE3F4FF);
  static const deep = Color(0xFF2E9FE6);

  /// Fondo de botones y enlaces: contraste 4.68 con blanco (AA).
  static const action = Color(0xFF0F78C2);

  static const canvas = Color(0xFFF4FAFF);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F2A4A);
  static const inkMuted = Color(0xFF4A6382);
  static const onAction = Color(0xFFFFFFFF);
  static const success = Color(0xFF1A8754);
  static const warning = Color(0xFFA86200);
  static const danger = Color(0xFFC9372C);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const full = 999.0;
}
