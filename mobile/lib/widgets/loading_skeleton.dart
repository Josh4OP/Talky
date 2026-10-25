import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'surface_card.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = reduceMotion ? 0.7 : 0.45 + _controller.value * 0.35;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class AnalysisListSkeleton extends StatelessWidget {
  const AnalysisListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const SkeletonBox(height: 48, width: 48, radius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        height: 13,
                        width: 180 + (i * 18).toDouble(),
                      ),
                      const SizedBox(height: 9),
                      const SkeletonBox(height: 10, width: 120),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SkeletonBox(height: 24, width: 62, radius: 999),
              ],
            ),
          ),
          if (i != count - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
