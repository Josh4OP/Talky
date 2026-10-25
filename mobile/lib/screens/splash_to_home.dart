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
  static const _mascotSize = 180.0;

  /// Ojo del loro en el lienzo de 512 de la mascota.
  static const _eye = Offset(320 / 512, 156 / 512);

  final _mascotKey = GlobalKey();
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
    _origin = _eyePosition();
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

  Offset _eyePosition() {
    final mascot = _mascotKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = context.findRenderObject() as RenderBox?;
    if (mascot == null || stack == null) return Offset.zero;
    final topLeft = mascot.localToGlobal(Offset.zero, ancestor: stack);
    return topLeft + Offset(_eye.dx * mascot.size.width, _eye.dy * mascot.size.height) + widget.originAdjust;
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
      child: SkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _float,
                builder: (context, child) =>
                    Transform.translate(offset: Offset(0, 4 * math.sin(2 * math.pi * _float.value)), child: child),
                child: TalkyMascot(
                  key: _mascotKey,
                  state: failed ? MascotState.sad : MascotState.silhouette,
                  size: _mascotSize,
                ),
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
