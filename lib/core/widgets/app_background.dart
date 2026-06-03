import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(
            color: AppColors.backgroundPrimary, child: SizedBox.expand()),

        Positioned(
          top: -300,
          left: -300,
          child: _GlowOrb(
            size: 600,
            color: AppColors.accentPurple.withOpacity(0.26),
          ),
        ),

        Positioned(
          top: 180,
          right: -300,
          child: _GlowOrb(
            size: 600,
            color: AppColors.accentPurple.withOpacity(0.26),
          ),
        ),

        Positioned(
          bottom: 220,
          left: -300,
          child: _GlowOrb(
            size: 500,
            color: AppColors.accentPurple.withOpacity(0.26),
          ),
        ),

        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}
