import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Estados de la mascota. Las imágenes salen de los bocetos de marca (`mobile/Vocetos/`).
enum MascotState {
  /// Inicio e historial: respira y se balancea.
  normal,

  /// Procesando: inclina la cabeza y el bombillo brilla.
  thinking,

  /// Resultados: rebota al ritmo de la voz.
  talking,

  /// Error de la API. Sin imagen propia todavía: usa la de pensando con un sacudón.
  surprised,

  /// Sin conexión. Sin imagen propia todavía: usa la normal, inclinada y apagada.
  sad,

  /// Splash: silueta blanca sobre el cielo.
  silhouette,
}

const _assets = {
  MascotState.normal: 'assets/mascot/normal.png',
  MascotState.thinking: 'assets/mascot/thinking.png',
  MascotState.talking: 'assets/mascot/talking.png',
  MascotState.surprised: 'assets/mascot/thinking.png',
  MascotState.sad: 'assets/mascot/normal.png',
  MascotState.silhouette: 'assets/mascot/silhouette.png',
};

String mascotAsset(MascotState state) => _assets[state]!;

/// Ojo del loro en la silueta, como fracción de la imagen (origen del revelado del splash).
const silhouetteEye = Offset(0.628, 0.383);

/// Bombillo de la imagen de pensando, como fracción de la imagen.
const _bulb = Offset(0.775, 0.24);

/// Movimiento de un instante `t` del ciclo (0 a 1). Función pura para poder probarla.
class MascotMotion {
  const MascotMotion({this.dy = 0, this.dx = 0, this.angle = 0, this.scale = 1, this.glow = 0});

  /// Desplazamiento como fracción del tamaño.
  final double dy;
  final double dx;

  /// Grados, sentido horario positivo, alrededor de las patas.
  final double angle;
  final double scale;

  /// Intensidad del brillo del bombillo (0 a 1).
  final double glow;

  static const still = MascotMotion();

  factory MascotMotion.at(MascotState state, double t) {
    final w = 2 * math.pi * t;
    double wave(double k, [double phase = 0]) => math.sin(k * w + phase);
    return switch (state) {
      MascotState.normal => MascotMotion(scale: 1 + 0.015 * wave(1), angle: 2 * wave(1, math.pi / 2)),
      MascotState.thinking => MascotMotion(angle: -3 + 2.5 * wave(1), dy: 0.008 * wave(2), glow: 0.5 + 0.5 * wave(3)),
      MascotState.talking => MascotMotion(dy: -0.02 * wave(6).abs(), scale: 1 + 0.02 * wave(6).abs()),
      MascotState.surprised => MascotMotion(dx: t < 0.2 ? 0.012 * wave(25) : 0, dy: -0.02 * math.max(0, wave(2))),
      MascotState.sad => MascotMotion(angle: 6 + wave(1), dy: 0.01, scale: 1 + 0.006 * wave(1)),
      MascotState.silhouette => MascotMotion(scale: 1 + 0.012 * wave(1)),
    };
  }
}

/// El loro pirata animado por estado. Respeta "reducir movimiento".
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
    final size = widget.size;
    return Semantics(
      image: true,
      label: 'Talky, el loro pirata',
      child: SizedBox.square(
        dimension: size,
        child: RepaintBoundary(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: still ? 0 : 300),
            child: AnimatedBuilder(
              key: ValueKey(widget.state),
              animation: _cycle,
              child: _image(widget.state, size),
              builder: (context, image) {
                final m = still ? MascotMotion.still : MascotMotion.at(widget.state, _cycle.value);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (m.glow > 0) _BulbGlow(size: size, intensity: m.glow),
                    Transform.translate(
                      offset: Offset(m.dx * size, m.dy * size),
                      child: Transform.rotate(
                        angle: m.angle * math.pi / 180,
                        alignment: const Alignment(0, 0.9),
                        child: Transform.scale(scale: m.scale, alignment: Alignment.bottomCenter, child: image),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _image(MascotState state, double size) {
    final image = Image.asset(
      mascotAsset(state),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    if (state != MascotState.sad) return image;
    // Más apagado para "sin conexión" mientras no haya una imagen triste propia.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.6, 0.3, 0.1, 0, 20, //
        0.2, 0.7, 0.1, 0, 20,
        0.2, 0.3, 0.5, 0, 30,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }
}

class _BulbGlow extends StatelessWidget {
  const _BulbGlow({required this.size, required this.intensity});

  final double size;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.12;
    return Positioned(
      left: _bulb.dx * size - radius,
      top: _bulb.dy * size - radius,
      width: radius * 2,
      height: radius * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.9 * intensity),
              AppColors.tint40.withValues(alpha: 0.5 * intensity),
              AppColors.tint40.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
