import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marca de TALKY: una burbuja de voz con un pequeño pico de loro.
class TalkyLogo extends StatelessWidget {
  const TalkyLogo({
    super.key,
    this.markSize = 44,
    this.showWordmark = true,
    this.onDark = false,
    this.fontSize,
  });

  final double markSize;
  final bool showWordmark;
  final bool onDark;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TalkyMark(size: markSize),
        if (showWordmark) ...[
          SizedBox(width: markSize * 0.24),
          Text(
            'TALKY',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: fontSize ?? markSize * 0.58,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              height: 1,
              color: onDark ? Colors.white : AppColors.ink,
            ),
          ),
        ],
      ],
    );
  }
}

class TalkyMark extends StatelessWidget {
  const TalkyMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logotipo de TALKY',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(size * 0.30),
          boxShadow: [
            BoxShadow(
              color: AppColors.ocean.withValues(alpha: 0.24),
              blurRadius: size * 0.34,
              offset: Offset(0, size * 0.12),
            ),
          ],
        ),
        child: CustomPaint(painter: _MarkPainter()),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bubble = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.20, h * 0.22, w * 0.60, h * 0.44),
          Radius.circular(w * 0.16),
        ),
      )
      ..moveTo(w * 0.32, h * 0.64)
      ..lineTo(w * 0.27, h * 0.78)
      ..quadraticBezierTo(w * 0.29, h * 0.80, w * 0.34, h * 0.77)
      ..lineTo(w * 0.44, h * 0.67)
      ..close();

    canvas.drawPath(bubble, Paint()..color = Colors.white);

    final barPaint = Paint()
      ..color = AppColors.ocean
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.075;
    canvas.drawLine(
      Offset(w * 0.34, h * 0.47),
      Offset(w * 0.34, h * 0.40),
      barPaint,
    );
    canvas.drawLine(
      Offset(w * 0.45, h * 0.52),
      Offset(w * 0.45, h * 0.35),
      barPaint,
    );
    final teal = Paint()
      ..color = AppColors.turquoise
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.075;
    canvas.drawLine(
      Offset(w * 0.56, h * 0.49),
      Offset(w * 0.56, h * 0.39),
      teal,
    );
    canvas.drawLine(
      Offset(w * 0.67, h * 0.46),
      Offset(w * 0.67, h * 0.42),
      teal,
    );

    // Pequeño pico que relaciona la marca con Talky.
    final beak = Path()
      ..moveTo(w * 0.72, h * 0.26)
      ..lineTo(w * 0.83, h * 0.30)
      ..lineTo(w * 0.73, h * 0.36)
      ..close();
    canvas.drawPath(beak, Paint()..color = AppColors.coral);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
