import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/theme/app_text_styles.dart';

class PlaysCounter extends StatelessWidget {
  const PlaysCounter({super.key, required this.count});

  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.play_arrow,
          color: AppColors.playsYellow,
          size: 12,
        ),
        const SizedBox(width: 4),
        Text('$count plays', style: AppTextStyles.playsText),
      ],
    );
  }
}
