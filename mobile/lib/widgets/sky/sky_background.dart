import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/app_colors.dart';
import 'cloud_layer_painter.dart';

/// Cielo de marca con nubes vivas. Lo usan el splash y la pantalla sin conexión.
class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, this.child});

  final Widget? child;

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.tint80, AppColors.primary, AppColors.tint60],
    stops: [0, 0.55, 1],
  );

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SkyBackground.gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: CloudLayerPainter(time: _time, moving: !MediaQuery.disableAnimationsOf(context)),
            ),
          ),
          ?widget.child,
        ],
      ),
    );
  }
}
