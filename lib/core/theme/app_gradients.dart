import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  AppGradients._();

  // Solid purple — used for primary buttons
  static const LinearGradient primaryButton = LinearGradient(
    colors: [AppColors.accentPurpleLight, AppColors.accentPurpleLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Purple gradient — used for SVIP badge
  static const LinearGradient svipBadge = LinearGradient(
    colors: [AppColors.accentPurple, Color(0xFF9B59F5)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Card overlay — transparent → black bottom overlay on thumbnails
  static const LinearGradient cardOverlay = LinearGradient(
    colors: [Colors.transparent, Colors.black],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Radial purple glow — used behind onboarding images
  // 0x4D = ~30% opacity of #7B3FE4
  static const RadialGradient backgroundPurple = RadialGradient(
    colors: [Color(0x4D7B3FE4), Colors.transparent],
    center: Alignment.center,
    radius: 0.8,
  );
}
