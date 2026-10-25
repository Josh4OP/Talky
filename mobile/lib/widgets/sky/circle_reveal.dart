import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Recorta a un círculo de centro y radio dados (revelado del splash hacia el inicio).
class CircleRevealClipper extends CustomClipper<Path> {
  const CircleRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(CircleRevealClipper old) => old.center != center || old.radius != radius;
}

/// Punto blanco que nace en el ojo del loro y anillo brillante del borde del círculo.
class RevealPainter extends CustomPainter {
  RevealPainter({required this.center, required this.dot, required this.expansion, required this.finalRadius})
    : super(repaint: Listenable.merge([dot, expansion]));

  static const dotRadius = 9.0;

  final Offset center;
  final Animation<double> dot;
  final Animation<double> expansion;
  final double finalRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = expansion.value;
    final radius = grow == 0 ? dotRadius * dot.value : dotRadius + (finalRadius - dotRadius) * grow;
    final fill = grow < 0.2 ? 1 - grow / 0.2 : 0.0;
    if (dot.value > 0 && fill > 0) {
      canvas.drawCircle(
        center,
        radius + 8,
        Paint()
          ..color = AppColors.tint40.withValues(alpha: 0.8 * fill)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(center, radius, Paint()..color = AppColors.surface.withValues(alpha: fill));
    }
    final ring = 1 - grow;
    if (grow > 0 && ring > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = AppColors.surface.withValues(alpha: 0.5 * ring)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.surface.withValues(alpha: 0.9 * ring),
      );
    }
  }

  @override
  bool shouldRepaint(RevealPainter old) => old.center != center || old.finalRadius != finalRadius;
}
