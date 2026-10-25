import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Etiqueta compacta para estados, métricas y categorías.
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    this.icon,
    this.foreground = AppColors.ocean,
    this.background = AppColors.blueSoft,
    this.borderColor,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;
  final Color? borderColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor ?? background,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
