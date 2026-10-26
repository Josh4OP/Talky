import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Encabezado de sección con antetítulo ("LO ESENCIAL"), título y subtítulo.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.eyebrow, required this.title, this.subtitle, this.trailing});

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: AppText.overline.copyWith(color: AppColors.action)),
                const SizedBox(height: 2),
                Semantics(header: true, child: Text(title, style: AppText.heading)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.caption.copyWith(color: AppColors.inkMuted)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Aviso obligatorio cuando la interfaz muestra datos de ejemplo.
class DemoBanner extends StatelessWidget {
  const DemoBanner({
    super.key,
    this.message = 'Estás viendo datos de ejemplo. No provienen de tu audio ni de tu historial.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppText.caption.copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña redondeada ("Ejemplo", "PASO 1 DE 2").
class AppPill extends StatelessWidget {
  const AppPill({super.key, required this.label, this.color = AppColors.action, this.background = AppColors.tint20});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label, style: AppText.overline.copyWith(color: color, fontSize: 12)),
    );
  }
}

/// Onda de la grabación: barras que siguen el nivel real del micrófono.
///
/// Los niveles llegan unas 16 veces por segundo; un solo reloj a la frecuencia de la pantalla desliza las
/// barras de forma continua entre muestra y muestra y suaviza sus alturas, para que se vea fluida sin
/// animar cada barra por separado. Con "reducir animaciones" solo se redibuja al llegar cada nivel.
class RecordingWaveform extends StatefulWidget {
  const RecordingWaveform({super.key, required this.levels, this.height = 56, this.bars = 32});

  final Stream<double> levels;
  final double height;
  final int bars;

  @override
  State<RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<RecordingWaveform> with SingleTickerProviderStateMixin {
  late final _wave = _WaveState(widget.bars);
  late final Ticker _ticker = createTicker(_wave.tick);
  StreamSubscription<double>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.levels.listen(_wave.push);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wave.still = MediaQuery.disableAnimationsOf(context);
    if (_wave.still && _ticker.isActive) _ticker.stop();
    if (!_wave.still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(painter: _WaveformPainter(_wave)),
        ),
      ),
    );
  }
}

/// Estado de la onda: niveles recibidos, alturas suavizadas y fase del desplazamiento.
class _WaveState extends ChangeNotifier {
  _WaveState(int bars)
    : targets = List.filled(bars + 1, _floor, growable: true),
      shown = List.filled(bars + 1, _floor, growable: true);

  static const _floor = 0.05;

  /// Fracción de la distancia al nivel real que se recorre por cuadro de 60 Hz.
  static const _smoothing = 0.25;

  final List<double> targets;
  final List<double> shown;
  bool still = false;

  /// De 0 a 1: cuánto se ha deslizado la onda desde el último nivel recibido.
  double phase = 0;
  Duration _lastTick = Duration.zero;
  Duration _lastSample = Duration.zero;
  Duration _interval = const Duration(milliseconds: 60);

  void push(double level) {
    targets
      ..removeAt(0)
      ..add(math.max(_floor, level));
    shown
      ..removeAt(0)
      ..add(shown.last);
    if (_lastTick > _lastSample) {
      _interval = _lastTick - _lastSample;
      _lastSample = _lastTick;
    }
    phase = 0;
    if (still) {
      shown.setAll(0, targets);
      notifyListeners();
    }
  }

  void tick(Duration elapsed) {
    final frames = (elapsed - _lastTick).inMicroseconds / 16667;
    _lastTick = elapsed;
    final k = 1 - math.pow(1 - _smoothing, frames.clamp(0, 4));
    for (var i = 0; i < shown.length; i++) {
      shown[i] += (targets[i] - shown[i]) * k;
    }
    final sinceSample = (elapsed - _lastSample).inMicroseconds / math.max(1, _interval.inMicroseconds);
    phase = sinceSample.clamp(0.0, 1.0);
    notifyListeners();
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.wave) : super(repaint: wave);

  final _WaveState wave;

  @override
  void paint(Canvas canvas, Size size) {
    final values = wave.shown;
    final visible = values.length - 1;
    final step = size.width / visible;
    final barWidth = math.min(5.0, step * 0.6);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < values.length; i++) {
      // La barra más nueva queda en la última ranura; todas se deslizan a la izquierda entre muestras.
      final x = step * (i - 0.5 - wave.phase);
      final h = size.height * values[i];
      final rect = Rect.fromCenter(center: Offset(x, size.height / 2), width: barWidth, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        Paint()..color = Color.lerp(AppColors.tint60, AppColors.action, values[i])!,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.wave != wave;
}

/// Tarjeta gris que ocupa el lugar de un elemento mientras carga.
class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key, this.height = 76});

  final double height;

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.surface, AppColors.tint20, _controller.value),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
