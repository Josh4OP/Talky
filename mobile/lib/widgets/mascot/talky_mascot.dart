import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'parrot_geometry.dart';
import 'svg_path.dart';

/// Estados de la mascota (variantes del componente "Mascota" de Figma).
enum MascotState {
  /// Inicio e historial: respira, mueve el sombrero y saluda.
  normal,

  /// Procesando: mira hacia arriba, bombillo y chispas.
  thinking,

  /// Resultados: abre el pico y salen ondas de sonido.
  talking,

  /// Error de la API.
  surprised,

  /// Sin conexión.
  sad,

  /// Splash: silueta blanca sobre el cielo.
  silhouette,
}

const _base = {
  'shadow', 'tail', 'foot_back', 'foot_front', 'body', 'belly', 'wing', 'head', 'face', //
  'beak_lower', 'beak_upper', 'hat_crown', 'hat_brim', 'hat_mark',
};

const _extras = <MascotState, Set<String>>{
  MascotState.normal: {'eye_happy', 'fx_greet'},
  MascotState.thinking: {'eye_open', 'eye_shine', 'fx_bulb', 'fx_rays', 'fx_sparkle_a', 'fx_sparkle_b'},
  MascotState.talking: {'eye_happy', 'fx_wave_a', 'fx_wave_b'},
  MascotState.surprised: {'eye_open', 'eye_shine'},
  MascotState.sad: {'eye_sad'},
  MascotState.silhouette: {'eye_happy'},
};

const _headGroup = {
  'head', 'face', 'eye_happy', 'eye_open', 'eye_shine', 'eye_sad', //
  'beak_lower', 'beak_upper', 'hat_crown', 'hat_brim', 'hat_mark',
};

const _silhouetteOutlined = {'wing', 'head', 'beak_upper', 'hat_crown', 'hat_brim', 'tail'};

/// Capas visibles de un estado, en orden de pintado.
List<ParrotLayer> visibleLayers(MascotState state) => [
  for (final layer in parrotLayers)
    if ((_base.contains(layer.name) || _extras[state]!.contains(layer.name)) &&
        !(state == MascotState.silhouette && layer.name == 'shadow'))
      layer,
];

/// Pose de un instante `t` del ciclo (0 a 1). Función pura para poder probarla.
class MascotPose {
  const MascotPose({
    this.breath = 1,
    this.lift = 0,
    this.headTilt = 0,
    this.rotation = const {},
    this.offset = const {},
    this.opacity = const {},
    this.scale = const {},
  });

  /// Escala de todo el cuerpo alrededor de las patas.
  final double breath;
  final double lift;

  /// Grados de la cabeza (con sombrero y pico) alrededor del cuello.
  final double headTilt;
  final Map<String, double> rotation;
  final Map<String, Offset> offset;
  final Map<String, double> opacity;
  final Map<String, double> scale;

  static const still = MascotPose();

  factory MascotPose.at(MascotState state, double t) {
    final w = 2 * math.pi * t;
    double wave(double k, [double phase = 0]) => math.sin(k * w + phase);
    double pulse(double k, [double phase = 0]) => math.max(0, wave(k, phase));
    final breath = 1 + 0.015 * wave(1);
    final blink = t > 0.92 && t < 0.97 ? 0.15 : 1.0;
    return switch (state) {
      MascotState.normal => MascotPose(
        breath: breath,
        rotation: {'hat_crown': 2 * wave(1), 'hat_brim': 2 * wave(1), 'hat_mark': 2 * wave(1)},
        opacity: {'fx_greet': 0.25 + 0.75 * pulse(1)},
      ),
      MascotState.thinking => MascotPose(
        breath: breath,
        headTilt: -4 + 2 * wave(1),
        rotation: {'wing': -28 + 5 * wave(1)},
        offset: const {'eye_open': Offset(3, -5), 'eye_shine': Offset(3, -5)},
        scale: {
          'eye_open': blink,
          'eye_shine': blink,
          'fx_sparkle_a': 0.6 + 0.4 * wave(2),
          'fx_sparkle_b': 0.6 + 0.4 * wave(2, math.pi),
        },
        opacity: {'fx_bulb': 0.7 + 0.3 * wave(3), 'fx_rays': pulse(2)},
      ),
      MascotState.talking => MascotPose(
        breath: breath,
        rotation: {'beak_lower': 11 + 11 * wave(8), 'wing': 22 + 10 * wave(2)},
        opacity: {'fx_wave_a': pulse(4), 'fx_wave_b': pulse(4, -1.2)},
      ),
      MascotState.surprised => MascotPose(
        breath: breath,
        lift: -4 * pulse(2),
        rotation: const {'beak_lower': 26},
        scale: {'eye_open': blink, 'eye_shine': blink},
      ),
      MascotState.sad => MascotPose(
        breath: 1 + 0.008 * wave(1),
        headTilt: 3,
        rotation: {'hat_crown': -6 + 1.5 * wave(1), 'hat_brim': -6 + 1.5 * wave(1), 'hat_mark': -6 + 1.5 * wave(1)},
      ),
      MascotState.silhouette => MascotPose(breath: breath),
    };
  }
}

/// El loro pirata animado. Dibuja con trazos (sin imágenes) y respeta "reducir movimiento".
class TalkyMascot extends StatefulWidget {
  const TalkyMascot({super.key, required this.state, this.size = 160});

  final MascotState state;
  final double size;

  @override
  State<TalkyMascot> createState() => _TalkyMascotState();
}

class _TalkyMascotState extends State<TalkyMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cycle
        ..stop()
        ..value = 0;
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      image: true,
      label: 'Talky, el loro pirata',
      child: RepaintBoundary(
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: still ? 0 : 300),
          child: CustomPaint(
            key: ValueKey(widget.state),
            size: Size.square(widget.size),
            painter: MascotPainter(state: widget.state, progress: _cycle, animate: !still),
          ),
        ),
      ),
    );
  }
}

class MascotPainter extends CustomPainter {
  MascotPainter({required this.state, required this.progress, this.animate = true}) : super(repaint: progress);

  final MascotState state;
  final Animation<double> progress;
  final bool animate;

  static final Map<String, Path> _paths = {for (final l in parrotLayers) l.name: parseSvgPath(l.path)};

  @override
  void paint(Canvas canvas, Size size) {
    final pose = animate ? MascotPose.at(state, progress.value) : MascotPose.still;
    canvas.save();
    canvas.scale(size.width / 512, size.height / 512);
    _around(canvas, const Offset(256, 456), () {
      canvas.translate(0, pose.lift);
      canvas.scale(pose.breath);
    });
    for (final layer in visibleLayers(state)) {
      canvas.save();
      if (_headGroup.contains(layer.name) && pose.headTilt != 0) {
        _around(canvas, const Offset(300, 200), () => canvas.rotate(_rad(pose.headTilt)));
      }
      final shift = pose.offset[layer.name];
      if (shift != null) canvas.translate(shift.dx, shift.dy);
      final degrees = pose.rotation[layer.name];
      if (degrees != null) _around(canvas, layer.pivot, () => canvas.rotate(_rad(degrees)));
      final scale = pose.scale[layer.name];
      if (scale != null) _around(canvas, layer.pivot, () => canvas.scale(scale));
      _paintLayer(canvas, layer, pose.opacity[layer.name] ?? 1);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintLayer(Canvas canvas, ParrotLayer layer, double opacity) {
    if (opacity <= 0) return;
    final path = _paths[layer.name]!;
    final silhouette = state == MascotState.silhouette;
    final color = silhouette ? (layer.name == 'eye_happy' ? AppColors.primary : AppColors.surface) : layer.color;
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..isAntiAlias = true;
    if (layer.stroke != null) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer.stroke!
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (silhouette && layer.name == 'hat_mark') paint.color = AppColors.primary;
    }
    canvas.drawPath(path, paint);
    if (silhouette && _silhouetteOutlined.contains(layer.name)) {
      // Contorno interior que separa las piezas, como en el boceto del splash.
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.primary,
      );
      canvas.restore();
    }
  }

  static void _around(Canvas canvas, Offset pivot, VoidCallback transform) {
    canvas.translate(pivot.dx, pivot.dy);
    transform();
    canvas.translate(-pivot.dx, -pivot.dy);
  }

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(MascotPainter old) => old.state != state || old.animate != animate;
}
