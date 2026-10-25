import 'package:flutter/material.dart';

/// Paleta oficial de TALKY.
///
/// El azul profundo y el turquesa vienen del plumaje de Talky; el coral se usa
/// como acento puntual para llamados a la acción y datos destacados.
abstract final class AppColors {
  // Marca
  static const ocean = Color(0xFF1157B5);
  static const oceanDark = Color(0xFF0A3A78);
  static const oceanDeep = Color(0xFF082B5A);
  static const blue = Color(0xFF2B7DE9);
  static const blueSoft = Color(0xFFE7F0FE);
  static const blueMist = Color(0xFFF3F7FE);

  static const turquoise = Color(0xFF11B5A4);
  static const turquoiseDark = Color(0xFF087F74);
  static const turquoiseSoft = Color(0xFFDFF8F4);

  static const coral = Color(0xFFFF8A4C);
  static const coralDark = Color(0xFFC9501A);
  static const coralSoft = Color(0xFFFFEEE4);

  // Neutros
  static const ink = Color(0xFF11253F);
  static const inkSoft = Color(0xFF50627A);
  static const inkMuted = Color(0xFF7B8BA0);
  static const canvas = Color(0xFFF7F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF0F4FA);
  static const border = Color(0xFFE2E9F2);
  static const borderStrong = Color(0xFFCBD7E6);

  // Semánticos
  static const success = Color(0xFF16835B);
  static const successSoft = Color(0xFFE4F7EE);
  static const warning = Color(0xFFB36B00);
  static const warningSoft = Color(0xFFFFF3DC);
  static const danger = Color(0xFFC43D3D);
  static const dangerSoft = Color(0xFFFDECEC);

  // Gradientes
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF0D3F82), Color(0xFF1566C9), Color(0xFF1889C9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const creamGradient = LinearGradient(
    colors: [Color(0xFFF2F7FF), Color(0xFFFBFDFF), Color(0xFFF3FBF9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const brandGradient = LinearGradient(
    colors: [ocean, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const turquoiseGradient = LinearGradient(
    colors: [Color(0xFF19C7B3), Color(0xFF0D9E90)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
