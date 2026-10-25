import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botón principal con degradado de marca, respuesta táctil y estado de carga.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.height = 54,
    this.gradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final double height;
  final Gradient? gradient;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  static const _labelStyle = TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.1,
  );

  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.loading ? '${widget.label}, cargando' : widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : (_hovered ? 1.012 : 1),
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            decoration: BoxDecoration(
              gradient: enabled
                  ? (widget.gradient ?? AppColors.brandGradient)
                  : const LinearGradient(
                      colors: [Color(0xFFB9C6D6), Color(0xFFA9B8CA)],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.ocean.withValues(
                          alpha: _hovered ? 0.32 : 0.22,
                        ),
                        blurRadius: _hovered ? 24 : 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled
                    ? () {
                        setState(() => _pressed = true);
                        widget.onPressed!();
                        Future<void>.delayed(
                          const Duration(milliseconds: 130),
                          () {
                            if (mounted) setState(() => _pressed = false);
                          },
                        );
                      }
                    : null,
                onHighlightChanged: (value) {
                  if (enabled && mounted) setState(() => _pressed = value);
                },
                borderRadius: BorderRadius.circular(16),
                splashColor: Colors.white.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisSize:
                        widget.expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.loading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      else if (widget.icon != null)
                        Icon(widget.icon, size: 20, color: Colors.white),
                      if (widget.loading || widget.icon != null)
                        const SizedBox(width: 10),
                      if (widget.expand)
                        Expanded(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: _labelStyle,
                          ),
                        )
                      else
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            style: _labelStyle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
