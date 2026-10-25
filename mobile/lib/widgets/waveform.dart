import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Onda decorativa del grabador. No representa niveles reales del micrófono:
/// solo comunica que la aplicación está escuchando.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    required this.active,
    this.height = 56,
    this.bars = 38,
    this.color = AppColors.ocean,
  });

  final bool active;
  final double height;
  final int bars;
  final Color color;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
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
    return Semantics(
      label: widget.active
          ? 'Grabación en curso, onda de audio activa'
          : 'Grabadora detenida',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return SizedBox(
              height: widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _WavePainter(
                  t: widget.active && !reduceMotion ? _controller.value : 0,
                  active: widget.active,
                  bars: widget.bars,
                  color: widget.color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.t,
    required this.active,
    required this.bars,
    required this.color,
  });

  final double t;
  final bool active;
  final int bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = math.max(3.0, size.width / (bars * 1.9));
    final gap = (size.width - bars * barWidth) / math.max(1, bars - 1);
    final centerY = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.45),
          color,
          AppColors.turquoise,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0; i < bars; i++) {
      final phase = (i / bars) * math.pi * 2;
      final envelope = 0.35 + 0.65 * math.sin((i / bars) * math.pi);
      final wave = active
          ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * math.pi * 4 + phase * 2.3))
          : 0.22 + 0.12 * math.sin(phase * 1.7);
      final height = math.max(4.0, size.height * envelope * wave * 0.9);
      final x = i * (barWidth + gap) + barWidth / 2;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.active != active ||
      oldDelegate.color != color ||
      oldDelegate.bars != bars;
}
