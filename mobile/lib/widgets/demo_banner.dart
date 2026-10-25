import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Aviso obligatorio cuando la interfaz muestra datos de ejemplo.
class DemoBanner extends StatelessWidget {
  const DemoBanner({
    super.key,
    this.message =
        'Estás viendo datos de ejemplo. No provienen de tu audio ni de tu historial.',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D39A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: compact ? 11.5 : 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7B4A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
