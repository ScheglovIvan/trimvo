import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundPrimary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentPurpleLight,
          secondary: AppColors.accentPurple,
          surface: AppColors.backgroundSecondary,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.bottomNavBackground,
          selectedItemColor: AppColors.bottomNavActive,
          unselectedItemColor: AppColors.bottomNavInactive,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
      );
}
