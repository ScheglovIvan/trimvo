import 'package:flutter/material.dart';
import 'package:trimvo/core/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Text(
          'Settings',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
