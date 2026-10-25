import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tarjeta base de TALKY con borde suave, radio consistente y una elevación
/// discreta al pasar el cursor. Se reutiliza en toda la aplicación.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.gradient,
    this.color,
    this.borderColor,
    this.radius = 22,
    this.elevated = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool elevated;
  final String? semanticLabel;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final isGradient = widget.gradient != null;

    final decoration = BoxDecoration(
      color: widget.gradient == null
          ? (widget.color ?? AppColors.surface)
          : null,
      gradient: widget.gradient,
      borderRadius: BorderRadius.circular(widget.radius),
      border: Border.all(
        color: widget.borderColor ??
            (isGradient ? Colors.transparent : AppColors.border),
      ),
      boxShadow: [
        if (widget.elevated || _hovered)
          BoxShadow(
            color: isGradient
                ? AppColors.ocean.withValues(alpha: 0.18)
                : AppColors.oceanDeep.withValues(alpha: _hovered ? 0.10 : 0.06),
            blurRadius: _hovered ? 28 : 20,
            offset: Offset(0, _hovered ? 12 : 8),
          ),
      ],
    );

    final content = Padding(padding: widget.padding, child: widget.child);

    return Semantics(
      button: interactive,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: interactive ? (_) => setState(() => _hovered = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          transformAlignment: Alignment.center,
          decoration: decoration,
          child: interactive
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      splashColor: (isGradient ? Colors.white : AppColors.ocean)
                          .withValues(alpha: 0.08),
                      highlightColor:
                          (isGradient ? Colors.white : AppColors.ocean)
                              .withValues(alpha: 0.04),
                      child: content,
                    ),
                  ),
                )
              : content,
        ),
      ),
    );
  }
}
