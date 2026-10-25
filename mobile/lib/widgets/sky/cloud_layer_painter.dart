import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_colors.dart';

/// Una capa de nubes: velocidad hacia la izquierda, opacidad y flotación propias.
class CloudLayer {
  const CloudLayer({
    required this.speed,
    required this.opacity,
    required this.color,
    required this.baseline,
    required this.amplitude,
    required this.period,
    required this.phase,
  });

  /// Píxeles por segundo.
  final double speed;
  final double opacity;
  final Color color;

  /// Altura del borde inferior de las nubes, como fracción del alto (0 arriba, 1 abajo).
  final double baseline;
  final double amplitude;
  final double period;
  final double phase;
}

const skyCloudLayers = [
  CloudLayer(speed: 8, opacity: 0.45, color: AppColors.tint40, baseline: 0.76, amplitude: 3, period: 6, phase: 0),
  CloudLayer(speed: 14, opacity: 0.7, color: AppColors.surface, baseline: 0.82, amplitude: 5, period: 5, phase: 1.3),
  CloudLayer(speed: 22, opacity: 1, color: AppColors.surface, baseline: 0.88, amplitude: 6, period: 7, phase: 2.1),
];

class _Puff {
  const _Puff(this.x, this.y, this.radius, this.blur);

  /// Posición horizontal como fracción del ancho del mosaico.
  final double x;
  final double y;
  final double radius;
  final double blur;
}

/// Nubes por código: cada nube son de 4 a 7 círculos difuminados con semilla fija, así que siempre se ven iguales.
/// Para cambiarlas por imágenes (`assets/brand/clouds_back.png`, `clouds_mid.png`, `clouds_front.png`),
/// basta con dibujar la imagen en lugar de los círculos dentro de [_paintTile]; el desplazamiento no cambia.
class CloudLayerPainter extends CustomPainter {
  CloudLayerPainter({required this.time, this.layers = skyCloudLayers, this.moving = true}) : super(repaint: time);

  /// Segundos transcurridos.
  final ValueListenable<double> time;
  final List<CloudLayer> layers;
  final bool moving;

  static final List<List<_Puff>> _puffs = _buildPuffs();

  static List<List<_Puff>> _buildPuffs() {
    final random = math.Random(42);
    return [
      for (var layer = 0; layer < skyCloudLayers.length; layer++)
        [
          for (var cloud = 0; cloud < 4; cloud++)
            for (var k = 0, n = 4 + random.nextInt(4); k < n; k++)
              _Puff(
                (cloud + 0.15 + random.nextDouble() * 0.3) / 4 + k * 0.045,
                -random.nextDouble() * 26,
                30 + random.nextDouble() * 30,
                2 + random.nextDouble() * 2,
              ),
        ],
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = moving ? time.value : 0.0;
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final baseY =
          size.height * layer.baseline + layer.amplitude * math.sin(2 * math.pi * seconds / layer.period + layer.phase);
      final shift = (seconds * layer.speed) % size.width;
      // La capa entera se compone con su opacidad para que los círculos superpuestos no se oscurezcan.
      canvas.saveLayer(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: layer.opacity));
      for (final tile in [-1, 0, 1]) {
        _paintTile(canvas, size, _puffs[i % _puffs.length], -shift + tile * size.width, baseY, layer.color);
      }
      canvas.drawRect(Rect.fromLTRB(0, baseY, size.width, size.height), Paint()..color = layer.color);
      canvas.restore();
    }
  }

  void _paintTile(Canvas canvas, Size size, List<_Puff> puffs, double dx, double baseY, Color color) {
    for (final puff in puffs) {
      canvas.drawCircle(
        Offset(dx + puff.x * size.width, baseY + puff.y),
        puff.radius,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, puff.blur),
      );
    }
  }

  @override
  bool shouldRepaint(CloudLayerPainter old) => old.moving != moving || old.layers != layers;
}
