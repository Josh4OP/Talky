import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fondo común de la aplicación: un degradado muy suave con manchas de color
/// que recuerdan el plumaje de Talky sin competir con el contenido.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.showBlobs = true,
  });

  final Widget child;
  final bool showBlobs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.creamGradient),
        ),
        if (showBlobs)
          const Positioned(
            top: -140,
            right: -90,
            child: _Blob(size: 330, color: Color(0x2217B9A8)),
          ),
        if (showBlobs)
          const Positioned(
            top: 120,
            left: -150,
            child: _Blob(size: 360, color: Color(0x161157B5)),
          ),
        if (showBlobs)
          const Positioned(
            bottom: -170,
            right: 40,
            child: _Blob(size: 390, color: Color(0x12FF8A4C)),
          ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Limita y centra el contenido para que se vea bien en móvil, tablet y web.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
