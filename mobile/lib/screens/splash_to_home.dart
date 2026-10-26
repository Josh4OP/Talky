import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot/talky_mascot.dart';
import '../widgets/sky/circle_reveal.dart';
import '../widgets/sky/sky_background.dart';

/// Splash de Talky: cielo con nubes mientras `loadApp` prepara la sesión y verifica el servidor;
/// luego un círculo que nace en el ojo del loro revela el inicio. Especificación en
/// `harness/prompts/tasks/Animacion-splash.md`.
class SplashToHome extends StatefulWidget {
  const SplashToHome({
    super.key,
    required this.loadApp,
    required this.home,
    this.originAdjust = Offset.zero,
    this.minDuration = const Duration(milliseconds: 1200),
  });

  final Future<void> Function() loadApp;
  final Widget home;
  final Offset originAdjust;
  final Duration minDuration;

  @override
  State<SplashToHome> createState() => _SplashToHomeState();
}

enum _Phase { loading, failed, revealing, done }

class _SplashToHomeState extends State<SplashToHome> with TickerProviderStateMixin {
  /// Rayitas de "voz" junto al pico: de ahí nace el círculo que revela el inicio.
  final _voiceKey = GlobalKey();
  late final _float = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  late final _dot = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final _expand = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _dotCurve = CurvedAnimation(parent: _dot, curve: Curves.easeOutBack);
  late final _expandCurve = CurvedAnimation(parent: _expand, curve: Curves.easeInOutCubic);

  var _phase = _Phase.loading;
  var _firstAttempt = true;
  ApiException _error = ApiException.connection();
  Offset _origin = Offset.zero;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _float.stop();
    } else if (!_float.isAnimating && _phase != _Phase.done) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _dotCurve.dispose();
    _expandCurve.dispose();
    _float.dispose();
    _dot.dispose();
    _expand.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final minimum = _firstAttempt ? Future<void>.delayed(widget.minDuration) : Future<void>.value();
    _firstAttempt = false;
    try {
      await Future.wait([widget.loadApp(), minimum]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = e is ApiException ? e : ApiException.connection();
      });
      return;
    }
    if (!mounted) return;
    _origin = _voicePosition();
    setState(() => _phase = _Phase.revealing);
    if (_still) {
      await _expand.animateTo(1, duration: const Duration(milliseconds: 200));
    } else {
      await _dot.forward();
      if (!mounted) return;
      await _expand.forward();
    }
    if (!mounted) return;
    _float.stop();
    setState(() => _phase = _Phase.done);
  }

  void _retry() {
    setState(() => _phase = _Phase.loading);
    _play();
  }

  Offset _voicePosition() {
    final voice = _voiceKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = context.findRenderObject() as RenderBox?;
    if (voice == null || stack == null) return Offset.zero;
    return voice.localToGlobal(voice.size.center(Offset.zero), ancestor: stack) + widget.originAdjust;
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.done) return widget.home;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final finalRadius = [
          Offset.zero,
          Offset(size.width, 0),
          Offset(0, size.height),
          Offset(size.width, size.height),
        ].map((corner) => (corner - _origin).distance).reduce(math.max);
        return Stack(
          fit: StackFit.expand,
          children: [
            _splash(),
            if (_phase == _Phase.revealing) _revealedHome(finalRadius),
            if (_phase == _Phase.revealing && !_still)
              IgnorePointer(
                child: CustomPaint(
                  painter: RevealPainter(
                    center: _origin,
                    dot: _dotCurve,
                    expansion: _expandCurve,
                    finalRadius: finalRadius,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _revealedHome(double finalRadius) {
    return AbsorbPointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_dotCurve, _expandCurve]),
        child: widget.home,
        builder: (context, home) {
          final t = _expandCurve.value;
          if (_still) return Opacity(opacity: t, child: home);
          final radius = t == 0 ? 0.0 : RevealPainter.dotRadius + (finalRadius - RevealPainter.dotRadius) * t;
          return ClipPath(
            clipper: CircleRevealClipper(center: _origin, radius: radius),
            child: Transform.scale(scale: 1.06 - 0.06 * t, child: home),
          );
        },
      ),
    );
  }

  Widget _splash() {
    final failed = _phase == _Phase.failed;
    return Semantics(
      label: failed ? null : 'Talky está cargando',
      child: Material(
        type: MaterialType.transparency,
        child: SkyBackground(
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) =>
                      Transform.translate(offset: Offset(0, 4 * math.sin(2 * math.pi * _float.value)), child: child),
                  child: failed
                      ? const TalkyMascot(state: MascotState.sad, size: 160)
                      : _Logo(voiceKey: _voiceKey, pulse: _float),
                ),
                const SizedBox(height: AppSpacing.lg),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: failed ? _ErrorCard(error: _error, onRetry: _retry) : const SizedBox(height: 0),
                ),
                const Spacer(flex: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  static const _networkHint = 'Revisa que el servidor esté encendido y que estés en la misma red.';

  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.isConnection ? 'No pudimos conectar con Talky' : 'Talky no pudo arrancar',
                style: AppText.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                error.isConnection ? _networkHint : error.message,
                style: AppText.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Logotipo del splash: el loro en silueta sobre el logotipo blanco "talky" (`assets/mascot/logo_white.png`,
/// limpiado desde `mobile/Vocetos/`). Entra con el loro cayendo con rebote y la palabra subiendo; luego de las
/// rayitas de voz salen ondas, como si Talky hablara. El círculo del revelado nace en esas rayitas.
class _Logo extends StatefulWidget {
  const _Logo({required this.voiceKey, required this.pulse});

  final GlobalKey voiceKey;

  /// Ciclo de flotación del splash; marca el ritmo de las ondas de voz.
  final Animation<double> pulse;

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  static const _parrot = 120.0;
  static const _wordWidth = 230.0;
  static const _wordHeight = _wordWidth * 353 / 900;

  /// Centro de las rayitas de voz dentro del logotipo, como fracción de la imagen.
  static const _voice = Offset(0.934, 0.186);

  late final _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  late final _drop = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
  );
  late final _rise = CurvedAnimation(
    parent: _entry,
    curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entry.value = 1;
    } else if (_entry.value == 0 && !_entry.isAnimating) {
      _entry.forward();
    }
  }

  @override
  void dispose() {
    _drop.dispose();
    _rise.dispose();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _drop,
          builder: (context, child) => Opacity(
            opacity: _drop.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -60 * (1 - _drop.value)),
              child: Transform.scale(scale: 0.7 + 0.3 * _drop.value, child: child),
            ),
          ),
          child: const TalkyMascot(state: MascotState.silhouette, size: _parrot),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedBuilder(
          animation: _rise,
          builder: (context, child) => Opacity(
            opacity: _rise.value,
            child: Transform.translate(offset: Offset(0, 24 * (1 - _rise.value)), child: child),
          ),
          child: SizedBox(
            width: _wordWidth,
            height: _wordHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.asset(
                  'assets/mascot/logo_white.png',
                  width: _wordWidth,
                  height: _wordHeight,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: 'Talky',
                ),
                Positioned(
                  left: _voice.dx * _wordWidth - 30,
                  top: _voice.dy * _wordHeight - 30,
                  child: SizedBox(
                    key: widget.voiceKey,
                    width: 60,
                    height: 60,
                    child: IgnorePointer(child: CustomPaint(painter: _VoiceWavesPainter(widget.pulse, _entry))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ondas blancas que salen de las rayitas de voz, dos por ciclo de flotación.
class _VoiceWavesPainter extends CustomPainter {
  _VoiceWavesPainter(this.pulse, this.entry) : super(repaint: Listenable.merge([pulse, entry]));

  final Animation<double> pulse;
  final Animation<double> entry;

  @override
  void paint(Canvas canvas, Size size) {
    if (entry.value < 1) return;
    final center = size.center(Offset.zero);
    for (final offset in const [0.0, 0.5]) {
      final t = (pulse.value * 2 + offset) % 1;
      canvas.drawCircle(
        center,
        6 + 22 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - t) + 0.5
          ..color = AppColors.surface.withValues(alpha: 0.7 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWavesPainter old) => old.pulse != pulse || old.entry != entry;
}
