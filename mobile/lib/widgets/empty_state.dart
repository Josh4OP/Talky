import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'gradient_button.dart';
import 'talky_mascot.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.mascotSize = 168,
    this.compact = false,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final double mascotSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: compact ? 20 : 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TalkyMascot(
                size: mascotSize,
                pose: TalkyPose.empty,
                backdrop: true,
                animate: !compact,
              ),
              SizedBox(height: compact ? 18 : 24),
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
                      height: 1.5,
                    ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                GradientButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  icon: Icons.add_rounded,
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 8),
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
