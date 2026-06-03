import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';
import 'package:trimvo/core/theme/app_text_styles.dart';

enum ButtonVariant { primary, secondary }

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.trailingIcon = false,
    this.width = double.infinity,
    this.height = 60,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool isLoading;
  final bool trailingIcon;
  final double width;
  final double height;

  bool get _isPrimary => variant == ButtonVariant.primary;
  bool get _isDisabled => onPressed == null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isDisabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: (isLoading || _isDisabled) ? null : onPressed,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: _isPrimary ? AppColors.accentPurpleLight : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: _isPrimary
                ? null
                : Border.all(color: AppColors.accentPurpleLight, width: 1.5),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: _isPrimary
                          ? AppTextStyles.buttonText
                          : AppTextStyles.buttonText.copyWith(
                              fontSize: 16,
                              color: AppColors.accentPurpleLight,
                            ),
                    ),
                    if (trailingIcon && _isPrimary) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
