import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/theme/app_gradients.dart';
import 'package:trimvo/core/theme/app_text_styles.dart';
import 'package:trimvo/core/theme/app_radius.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.textPrimary,
                ),
              )
            : Text(label, style: AppTextStyles.buttonText),
      ),
    );
  }
}
