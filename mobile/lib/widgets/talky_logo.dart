import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'talky_mascot.dart';

/// Marca de TALKY: una burbuja de voz con un pequeño pico de loro.
class TalkyLogo extends StatelessWidget {
  const TalkyLogo({
    super.key,
    this.markSize = 44,
    this.showWordmark = true,
    this.onDark = false,
    this.fontSize,
  });

  final double markSize;
  final bool showWordmark;
  final bool onDark;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TalkyMark(size: markSize),
        if (showWordmark) ...[
          SizedBox(width: markSize * 0.24),
          Text(
            'TALKY',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: fontSize ?? markSize * 0.58,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              height: 1,
              color: onDark ? Colors.white : AppColors.ink,
            ),
          ),
        ],
      ],
    );
  }
}

class TalkyMark extends StatelessWidget {
  const TalkyMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return TalkyMascot(
      size: size,
      pose: TalkyPose.welcome,
      animate: false,
      semanticLabel: 'Logotipo de TALKY',
    );
  }
}

