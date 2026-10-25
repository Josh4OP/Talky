import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Poses disponibles de Talky. Cada pantalla elige la que mejor acompaña el
/// momento: bienvenida, saludo, escucha, análisis, celebración, vacío o error.
enum TalkyPose { welcome, wave, listening, thinking, celebrate, empty, sorry }

/// Talky es una ilustración vectorial original dibujada en Flutter.
///
/// Al ser un `CustomPainter` se mantiene nítida en cualquier tamaño, no depende
/// de imágenes externas y puede animarse de forma sutil (respiración, parpadeo,
/// aleteo y chispas).
class TalkyMascot extends StatefulWidget {
  const TalkyMascot({
    super.key,
    this.size = 220,
    this.pose = TalkyPose.welcome,
    this.animate = true,
    this.backdrop = false,
    this.semanticLabel,
  });

  final double size;
  final TalkyPose pose;
  final bool animate;
  final bool backdrop;
  final String? semanticLabel;

  @override
  State<TalkyMascot> createState() => _TalkyMascotState();
}

class _TalkyMascotState extends State<TalkyMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant TalkyMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final label = widget.semanticLabel ?? _defaultLabel(widget.pose);

    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = widget.animate && !reduceMotion ? _controller.value : 0.0;
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _TalkyPainter(
                pose: widget.pose,
                t: t,
                backdrop: widget.backdrop,
              ),
            );
          },
        ),
      ),
    );
  }

  static String _defaultLabel(TalkyPose pose) => switch (pose) {
        TalkyPose.welcome => 'Talky, el loro azul y turquesa de TALKY, te da la bienvenida',
        TalkyPose.wave => 'Talky te saluda con la alas',
        TalkyPose.listening => 'Talky escucha atentamente',
        TalkyPose.thinking => 'Talky está analizando tu exposición',
        TalkyPose.celebrate => 'Talky celebra tus resultados',
        TalkyPose.empty => 'Talky te invita a crear tu primer análisis',
        TalkyPose.sorry => 'Talky te acompaña cuando algo sale mal',
      };
}

class _TalkyPainter extends CustomPainter {
  _TalkyPainter({
    required this.pose,
    required this.t,
    required this.backdrop,
  });

  final TalkyPose pose;
  final double t;
  final bool backdrop;

  static const _scale = 400.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _scale;
    canvas.save();
    canvas.scale(scale);

    final wave = math.sin(t * math.pi * 4);
    final bob = math.sin(t * math.pi * 2) * 3.2;
    final blink = t > 0.945 && t < 0.972;

    if (backdrop) _paintBackdrop(canvas);

    canvas.save();
    canvas.translate(0, bob);

    _paintShadow(canvas);
    _paintTail(canvas);
    _paintFeet(canvas);
    _paintBody(canvas);
    _paintBelly(canvas);

    if (pose == TalkyPose.celebrate) {
      _paintLeftWing(canvas, wave);
    }

    _paintHead(canvas);
    _paintCrest(canvas, wave);
    _paintFace(canvas, blink: blink);
    _paintBeak(canvas);
    _paintWing(canvas, wave);
    _paintAccessory(canvas, wave);

    canvas.restore();
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Fondo y accesorios
  // ---------------------------------------------------------------------------

  void _paintBackdrop(Canvas canvas) {
    final blob = Rect.fromCenter(
      center: const Offset(202, 192),
      width: 356,
      height: 356,
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE9F3FF), Color(0xFFE2FAF5), Color(0xFFF7FBFF)],
      ).createShader(blob);
    canvas.drawOval(blob, paint);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.turquoise.withValues(alpha: 0.22);
    canvas.drawCircle(const Offset(202, 192), 139, ring);

    final dot = Paint()..color = AppColors.turquoise.withValues(alpha: 0.75);
    final blueDot = Paint()..color = AppColors.blue.withValues(alpha: 0.55);
    final coralDot = Paint()..color = AppColors.coral.withValues(alpha: 0.85);

    canvas.drawCircle(const Offset(58, 112), 5.2, dot);
    canvas.drawCircle(const Offset(338, 96), 4.2, blueDot);
    canvas.drawCircle(const Offset(344, 260), 6.0, coralDot);
    canvas.drawCircle(const Offset(52, 286), 3.4, blueDot);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.blue.withValues(alpha: 0.22);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(338, 190), radius: 24),
      -1.1,
      1.5,
      false,
      arc,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(338, 190), radius: 34),
      -1.1,
      1.5,
      false,
      arc,
    );
  }

  void _paintShadow(Canvas canvas) {
    final shadow = Paint()
      ..color = AppColors.oceanDeep.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(206, 352), width: 200, height: 30),
      shadow,
    );
  }

  // ---------------------------------------------------------------------------
  // Cuerpo
  // ---------------------------------------------------------------------------

  void _paintTail(Canvas canvas) {
    final featherBlue = _gradient(
      const Rect.fromLTWH(60, 245, 115, 115),
      const [Color(0xFF2B86E6), Color(0xFF1054AC)],
    );
    final featherTeal = _gradient(
      const Rect.fromLTWH(52, 238, 110, 100),
      const [Color(0xFF27C9B7), Color(0xFF098F84)],
    );

    final back = Path()
      ..moveTo(138, 258)
      ..quadraticBezierTo(92, 285, 70, 338)
      ..quadraticBezierTo(64, 350, 78, 351)
      ..quadraticBezierTo(104, 352, 126, 322)
      ..quadraticBezierTo(140, 302, 151, 276)
      ..close();
    canvas.drawPath(back, featherBlue);

    final middle = Path()
      ..moveTo(150, 270)
      ..quadraticBezierTo(118, 304, 102, 341)
      ..quadraticBezierTo(98, 352, 112, 350)
      ..quadraticBezierTo(130, 345, 149, 320)
      ..quadraticBezierTo(158, 303, 166, 283)
      ..close();
    canvas.drawPath(middle, featherTeal);

    final top = Path()
      ..moveTo(164, 277)
      ..quadraticBezierTo(144, 306, 135, 332)
      ..quadraticBezierTo(133, 342, 144, 338)
      ..quadraticBezierTo(157, 331, 172, 307)
      ..quadraticBezierTo(181, 292, 185, 282)
      ..close();
    canvas.drawPath(
      top,
      _gradient(
        const Rect.fromLTWH(130, 275, 55, 70),
        const [Color(0xFF64B9FF), Color(0xFF2B7DE9)],
      ),
    );
  }

  void _paintBody(Canvas canvas) {
    final body = Path()
      ..moveTo(212, 152)
      ..cubicTo(282, 152, 312, 206, 310, 260)
      ..cubicTo(308, 315, 273, 342, 210, 342)
      ..cubicTo(147, 342, 112, 315, 110, 260)
      ..cubicTo(108, 206, 142, 152, 212, 152)
      ..close();

    canvas.drawPath(
      body,
      _gradient(
        const Rect.fromLTWH(108, 148, 204, 198),
        const [Color(0xFF4FA7FF), Color(0xFF1D6FD3), Color(0xFF1152A6)],
        stops: const [0, 0.58, 1],
      ),
    );

    // Luz suave en el costado izquierdo.
    final light = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.22), Colors.transparent],
      ).createShader(
        Rect.fromCircle(center: const Offset(150, 220), radius: 92),
      );
    canvas.drawPath(body, light);
  }

  void _paintBelly(Canvas canvas) {
    final belly = Path()
      ..moveTo(210, 210)
      ..cubicTo(249, 210, 270, 241, 268, 278)
      ..cubicTo(266, 318, 241, 334, 210, 334)
      ..cubicTo(179, 334, 154, 318, 152, 278)
      ..cubicTo(150, 241, 171, 210, 210, 210)
      ..close();

    canvas.drawPath(
      belly,
      _gradient(
        const Rect.fromLTWH(150, 210, 120, 126),
        const [Color(0xFFA6F5E8), Color(0xFF45D8C5), Color(0xFF11A99A)],
        stops: const [0, 0.55, 1],
      ),
    );

    final featherLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0A8C81).withValues(alpha: 0.26);
    for (var i = 0; i < 3; i++) {
      final y = 268.0 + i * 20;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(210, y), width: 62.0 - i * 8, height: 30),
        0.2,
        2.7,
        false,
        featherLine,
      );
    }
  }

  void _paintHead(Canvas canvas) {
    final head = Rect.fromCircle(center: const Offset(210, 166), radius: 82);
    canvas.drawCircle(
      head.center,
      head.width / 2,
      _gradient(
        Rect.fromLTWH(128, 84, 164, 164),
        const [Color(0xFF5AB0FF), Color(0xFF2477D8), Color(0xFF1257AE)],
        stops: const [0, 0.58, 1],
      ),
    );

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.20), Colors.transparent],
      ).createShader(
        Rect.fromCircle(center: const Offset(176, 126), radius: 78),
      );
    canvas.drawCircle(head.center, head.width / 2, glow);
  }

  void _paintCrest(Canvas canvas, double wave) {
    final sway = pose == TalkyPose.celebrate ? wave * 3.5 : wave * 1.2;

    final teal = _gradient(
      const Rect.fromLTWH(150, 46, 96, 100),
      const [Color(0xFF31D5C0), Color(0xFF0A9388)],
    );
    final blue = _gradient(
      const Rect.fromLTWH(165, 44, 86, 96),
      const [Color(0xFF4FA7FF), Color(0xFF155DB8)],
    );

    final feather1 = Path()
      ..moveTo(176, 102)
      ..cubicTo(160 + sway, 76, 164 + sway, 54, 180 + sway, 44)
      ..cubicTo(193 + sway, 60, 196 + sway, 82, 190, 104)
      ..close();
    canvas.drawPath(feather1, teal);

    final feather2 = Path()
      ..moveTo(205, 92)
      ..cubicTo(202 + sway, 62, 214 + sway, 40, 235 + sway, 35)
      ..cubicTo(244 + sway, 58, 238, 84, 222, 100)
      ..close();
    canvas.drawPath(feather2, blue);

    final feather3 = Path()
      ..moveTo(224, 101)
      ..cubicTo(231 + sway, 80, 249 + sway, 66, 264 + sway, 67)
      ..cubicTo(265 + sway, 88, 251, 106, 237, 111)
      ..close();
    canvas.drawPath(
      feather3,
      _gradient(
        const Rect.fromLTWH(220, 64, 48, 52),
        const [Color(0xFF65E3D3), Color(0xFF1BB7A7)],
      ),
    );

    // Base de las plumas para integrarlas con la cabeza.
    final base = Paint()..color = const Color(0xFF2A80DE);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(210, 102), width: 92, height: 26),
      base,
    );
  }

  // ---------------------------------------------------------------------------
  // Rostro
  // ---------------------------------------------------------------------------

  void _paintFace(Canvas canvas, {required bool blink}) {
    final mask = Path()
      ..moveTo(148, 162)
      ..cubicTo(151, 132, 178, 122, 210, 122)
      ..cubicTo(245, 122, 269, 136, 271, 164)
      ..cubicTo(272, 189, 251, 202, 230, 202)
      ..cubicTo(215, 202, 210, 195, 201, 195)
      ..cubicTo(190, 195, 187, 203, 171, 201)
      ..cubicTo(152, 199, 145, 182, 148, 162)
      ..close();
    final maskPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFBCE1FF).withValues(alpha: 0.55),
          const Color(0xFF8BC8F5).withValues(alpha: 0.28),
        ],
      ).createShader(const Rect.fromLTWH(145, 120, 130, 85));
    canvas.drawPath(mask, maskPaint);

    _paintEye(canvas, const Offset(182, 160), blink);
    _paintEye(canvas, const Offset(236, 160), blink);

    final brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0A3A72).withValues(alpha: 0.75);

    if (pose == TalkyPose.sorry) {
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(181, 139), width: 28, height: 17),
        math.pi + 0.35,
        1.2,
        false,
        brow,
      );
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(237, 139), width: 28, height: 17),
        -0.35,
        1.2,
        false,
        brow,
      );
    } else if (pose == TalkyPose.thinking) {
      canvas.drawLine(const Offset(170, 139), const Offset(193, 143), brow);
      canvas.drawLine(const Offset(225, 143), const Offset(248, 138), brow);
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(181, 143), width: 27, height: 15),
        3.35,
        1.1,
        false,
        brow,
      );
      canvas.drawArc(
        Rect.fromCenter(center: const Offset(237, 143), width: 27, height: 15),
        3.35,
        1.1,
        false,
        brow,
      );
    }

    final cheek = Paint()..color = const Color(0xFF12B8A6).withValues(alpha: 0.28);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(154, 190), width: 26, height: 14),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(265, 190), width: 26, height: 14),
      cheek,
    );
  }

  void _paintEye(Canvas canvas, Offset center, bool blink) {
    if (blink) {
      final closed = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF0B2C50);
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 24, height: 12),
        0.15,
        math.pi - 0.3,
        false,
        closed,
      );
      return;
    }

    final white = Paint()..color = Colors.white;
    canvas.drawCircle(center, 16.5, white);

    final pupil = Paint()..color = const Color(0xFF0B2C50);
    final look = pose == TalkyPose.thinking
        ? const Offset(1.4, -1.2)
        : pose == TalkyPose.sorry
            ? const Offset(-1.0, 1.6)
            : const Offset(0.6, 0.4);
    canvas.drawCircle(center + look, 8.2, pupil);

    final shine = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(center + look + const Offset(-2.4, -2.6), 2.7, shine);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF0A3A72).withValues(alpha: 0.16);
    canvas.drawCircle(center, 16.5, rim);
  }

  void _paintBeak(Canvas canvas) {
    final upper = Path()
      ..moveTo(193, 187)
      ..cubicTo(200, 179, 219, 179, 227, 188)
      ..cubicTo(230, 198, 220, 208, 210, 214)
      ..cubicTo(200, 208, 190, 199, 193, 187)
      ..close();
    canvas.drawPath(
      upper,
      _gradient(
        const Rect.fromLTWH(190, 178, 40, 38),
        const [Color(0xFFFFB36B), Color(0xFFF47A32), Color(0xFFD95A18)],
        stops: const [0, 0.6, 1],
      ),
    );

    final hook = Path()
      ..moveTo(210, 214)
      ..cubicTo(211, 222, 216, 224, 220, 219)
      ..cubicTo(219, 211, 215, 207, 210, 205)
      ..close();
    canvas.drawPath(hook, Paint()..color = const Color(0xFFC9501A));

    final lower = Path()
      ..moveTo(199, 209)
      ..cubicTo(205, 216, 216, 216, 222, 209)
      ..cubicTo(218, 221, 203, 224, 199, 209)
      ..close();
    canvas.drawPath(lower, Paint()..color = const Color(0xFFB84312));

    final nostril = Paint()..color = const Color(0xFF9B3A10);
    canvas.drawCircle(const Offset(203, 189), 1.6, nostril);
    canvas.drawCircle(const Offset(217, 189), 1.6, nostril);

    final smile = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8F2F0A);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(210, 209), width: 13, height: 7),
      0.1,
      math.pi - 0.2,
      false,
      smile,
    );
  }

  // ---------------------------------------------------------------------------
  // Alas, patas y objetos
  // ---------------------------------------------------------------------------

  void _paintWing(Canvas canvas, double wave) {
    final (angle, dx, dy) = switch (pose) {
      TalkyPose.wave => (-0.98 + wave * 0.20, 8.0, -24.0),
      TalkyPose.welcome => (-0.55 + wave * 0.05, 2.0, -12.0),
      TalkyPose.celebrate => (-1.18 + wave * 0.10, 6.0, -18.0),
      TalkyPose.listening => (-1.32, -8.0, -8.0),
      TalkyPose.thinking => (-1.15, -4.0, 6.0),
      TalkyPose.empty => (-0.25, 0.0, 8.0),
      TalkyPose.sorry => (0.32, 0.0, 10.0),
    };

    canvas.save();
    canvas.translate(278 + dx, 232 + dy);
    canvas.rotate(angle);

    final wing = Path()
      ..moveTo(0, 4)
      ..cubicTo(20, -8, 43, 6, 49, 36)
      ..cubicTo(55, 66, 43, 88, 24, 90)
      ..cubicTo(6, 92, -3, 70, -2, 40)
      ..cubicTo(-2, 24, -2, 12, 0, 4)
      ..close();

    canvas.drawPath(
      wing,
      _gradient(
        const Rect.fromLTWH(-5, -8, 62, 100),
        const [Color(0xFF3C96F0), Color(0xFF1663BE)],
      ),
    );

    final tip = Path()
      ..moveTo(27, 68)
      ..cubicTo(41, 66, 49, 76, 44, 88)
      ..cubicTo(36, 96, 22, 94, 17, 82)
      ..close();
    canvas.drawPath(
      tip,
      _gradient(
        const Rect.fromLTWH(16, 64, 32, 34),
        const [Color(0xFF39D6C2), Color(0xFF0A978B)],
      ),
    );

    final feather = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0D4E9A).withValues(alpha: 0.35);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(24, 42), width: 34, height: 42),
      -0.6,
      1.5,
      false,
      feather,
    );

    canvas.restore();
  }

  void _paintLeftWing(Canvas canvas, double wave) {
    canvas.save();
    canvas.translate(136, 224);
    canvas.rotate(1.05 - wave * 0.10);
    final wing = Path()
      ..moveTo(0, 2)
      ..cubicTo(-18, -8, -38, 6, -44, 34)
      ..cubicTo(-49, 62, -38, 82, -20, 84)
      ..cubicTo(-3, 86, 4, 66, 3, 38)
      ..cubicTo(3, 23, 2, 10, 0, 2)
      ..close();
    canvas.drawPath(
      wing,
      _gradient(
        const Rect.fromLTWH(-46, -8, 58, 94),
        const [Color(0xFF3C96F0), Color(0xFF1663BE)],
      ),
    );
    final tip = Path()
      ..moveTo(-24, 64)
      ..cubicTo(-37, 62, -44, 72, -39, 83)
      ..cubicTo(-31, 90, -18, 88, -14, 77)
      ..close();
    canvas.drawPath(
      tip,
      _gradient(
        const Rect.fromLTWH(-44, 60, 32, 32),
        const [Color(0xFF39D6C2), Color(0xFF0A978B)],
      ),
    );
    canvas.restore();
  }

  void _paintFeet(Canvas canvas) {
    final leg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEA7B35);
    canvas.drawLine(const Offset(181, 327), const Offset(179, 346), leg);
    canvas.drawLine(const Offset(235, 327), const Offset(237, 346), leg);

    final toe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF3924D);
    for (final foot in [const Offset(179, 346), const Offset(237, 346)]) {
      canvas.drawLine(foot, foot + const Offset(-14, 7), toe);
      canvas.drawLine(foot, foot + const Offset(-2, 10), toe);
      canvas.drawLine(foot, foot + const Offset(11, 7), toe);
    }
  }

  void _paintAccessory(Canvas canvas, double wave) {
    switch (pose) {
      case TalkyPose.listening:
        _paintMic(canvas);
      case TalkyPose.thinking:
        _paintThoughts(canvas);
      case TalkyPose.celebrate:
        _paintConfetti(canvas, wave);
      case TalkyPose.empty:
        _paintCard(canvas);
      case TalkyPose.sorry:
        _paintCloud(canvas);
      case TalkyPose.welcome:
      case TalkyPose.wave:
        _paintSparkles(canvas, wave);
    }
  }

  void _paintMic(Canvas canvas) {
    canvas.save();
    canvas.translate(120, 286);
    canvas.rotate(-0.18);

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -26, 20, 40),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      body,
      _gradient(
        const Rect.fromLTWH(-10, -26, 20, 40),
        const [Color(0xFF294A73), Color(0xFF102C4D)],
      ),
    );
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawLine(const Offset(-5, -18), const Offset(5, -18), grid);
    canvas.drawLine(const Offset(-5, -11), const Offset(5, -11), grid);
    canvas.drawLine(const Offset(-5, -4), const Offset(5, -4), grid);

    final stand = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF294A73);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, 12), width: 28, height: 24),
      0,
      math.pi,
      false,
      stand,
    );
    canvas.drawLine(const Offset(0, 24), const Offset(0, 34), stand);
    canvas.drawLine(const Offset(-9, 34), const Offset(9, 34), stand);
    canvas.restore();

    final sound = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.turquoise.withValues(alpha: 0.75);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(136, 294), radius: 28),
      -1.2,
      1.2,
      false,
      sound,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(136, 294), radius: 40),
      -1.2,
      1.2,
      false,
      sound..color = AppColors.turquoise.withValues(alpha: 0.35),
    );
  }

  void _paintThoughts(Canvas canvas) {
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.94);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = AppColors.blue.withValues(alpha: 0.24);

    canvas.drawCircle(const Offset(86, 110), 6, bubble);
    canvas.drawCircle(const Offset(104, 88), 9, bubble);
    final big = RRect.fromRectAndRadius(
      const Rect.fromLTWH(112, 28, 76, 50),
      const Radius.circular(18),
    );
    canvas.drawRRect(big, bubble);
    canvas.drawRRect(big, border);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.blue.withValues(alpha: 0.8);
    canvas.drawLine(const Offset(128, 45), const Offset(172, 45), line);
    canvas.drawLine(const Offset(128, 56), const Offset(158, 56), line);
    canvas.drawLine(const Offset(128, 67), const Offset(166, 67), line);

    final spark = Paint()..color = AppColors.coral.withValues(alpha: 0.9);
    _drawSpark(canvas, const Offset(320, 118), 7, spark);
    _drawSpark(
      canvas,
      const Offset(300, 70),
      4.5,
      Paint()..color = AppColors.turquoise.withValues(alpha: 0.9),
    );
  }

  void _paintConfetti(Canvas canvas, double wave) {
    final colors = [
      AppColors.coral,
      AppColors.turquoise,
      const Color(0xFFFFC94A),
      AppColors.blue,
    ];
    final points = <Offset>[
      const Offset(78, 86),
      const Offset(116, 58),
      const Offset(300, 64),
      const Offset(330, 112),
      const Offset(72, 190),
      const Offset(334, 202),
      const Offset(100, 296),
      const Offset(310, 292),
    ];
    for (var i = 0; i < points.length; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.9);
      final offset = points[i] + Offset(0, math.sin(t * math.pi * 2 + i) * 4);
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate((i.isEven ? 1 : -1) * (0.4 + wave * 0.3));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 13, height: 5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintCard(Canvas canvas) {
    canvas.save();
    canvas.translate(306, 292);
    canvas.rotate(-0.12);
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-38, -46, 76, 92),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      card.shift(const Offset(0, 5)),
      Paint()
        ..color = AppColors.oceanDeep.withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(card, Paint()..color = Colors.white);
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.borderStrong,
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.blue.withValues(alpha: 0.45);
    canvas.drawLine(const Offset(-24, -22), const Offset(16, -22), line);
    canvas.drawLine(const Offset(-24, -8), const Offset(4, -8), line);
    final plus = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.turquoise;
    canvas.drawLine(const Offset(-8, 22), const Offset(8, 22), plus);
    canvas.drawLine(const Offset(0, 14), const Offset(0, 30), plus);
    canvas.restore();
  }

  void _paintCloud(Canvas canvas) {
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(const Offset(78, 118), 16, cloud);
    canvas.drawCircle(const Offset(102, 106), 21, cloud);
    canvas.drawCircle(const Offset(128, 116), 14, cloud);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(70, 112, 66, 22),
        const Radius.circular(11),
      ),
      cloud,
    );

    final rain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.blue.withValues(alpha: 0.45);
    canvas.drawLine(const Offset(88, 142), const Offset(84, 152), rain);
    canvas.drawLine(const Offset(108, 142), const Offset(104, 152), rain);
  }

  void _paintSparkles(Canvas canvas, double wave) {
    final spark = Paint()
      ..color = AppColors.coral.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.3);
    final teal = Paint()..color = AppColors.turquoise.withValues(alpha: 0.9);
    final blue = Paint()..color = AppColors.blue.withValues(alpha: 0.7);

    _drawSpark(canvas, const Offset(64, 124), 7.5, spark);
    _drawSpark(canvas, const Offset(338, 150), 5.5, teal);
    _drawSpark(canvas, const Offset(88, 232), 4.5, blue);
    _drawSpark(
      canvas,
      Offset(318, 86 + math.sin(t * math.pi * 2) * 3),
      3.5,
      Paint()..color = const Color(0xFFFFC94A),
    );
    canvas.drawCircle(
      Offset(58, 196 + wave * 2),
      3.2,
      Paint()..color = AppColors.blue.withValues(alpha: 0.35),
    );
  }

  void _drawSpark(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * 0.25,
        center.dy - radius * 0.25,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.25,
        center.dy + radius * 0.25,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.25,
        center.dy + radius * 0.25,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.25,
        center.dy - radius * 0.25,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  Paint _gradient(
    Rect rect,
    List<Color> colors, {
    List<double>? stops,
  }) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
        stops: stops,
      ).createShader(rect);
  }

  @override
  bool shouldRepaint(covariant _TalkyPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.t != t ||
      oldDelegate.backdrop != backdrop;
}
