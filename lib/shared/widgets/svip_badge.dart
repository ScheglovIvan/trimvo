import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_gradients.dart';
import 'package:trimvo/core/theme/app_text_styles.dart';

class SvipBadge extends StatelessWidget {
  const SvipBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        gradient: AppGradients.svipBadge,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👑', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text('SVIP', style: AppTextStyles.badgeText),
        ],
      ),
    );
  }
}
