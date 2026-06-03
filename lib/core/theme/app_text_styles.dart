import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Purple "Awaken" hero word
  static TextStyle get heroTitle => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        color: AppColors.accentPurple,
      );

  // White hero subtitle line
  static TextStyle get heroSubtitle => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      );

  static TextStyle get sectionTitle => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardTitle => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get playsText => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.playsYellow,
      );

  static TextStyle get badgeText => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get captionText => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );
}
