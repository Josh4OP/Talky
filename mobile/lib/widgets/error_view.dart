import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'gradient_button.dart';
import 'talky_mascot.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Algo no salió como esperábamos',
    this.onRetry,
    this.retryLabel = 'Intentar de nuevo',
    this.secondaryLabel,
    this.onSecondary,
    this.mascotSize = 160,
    this.compact = false,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final double mascotSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: compact ? 18 : 30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TalkyMascot(
                size: mascotSize,
                pose: TalkyPose.sorry,
                backdrop: true,
                animate: !compact,
              ),
              SizedBox(height: compact ? 16 : 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                      height: 1.55,
                    ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 22),
                GradientButton(
                  label: retryLabel,
                  onPressed: onRetry,
                  icon: Icons.refresh_rounded,
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3C7C7)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B2C2C),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}
