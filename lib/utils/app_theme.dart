import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary palette — matches TinyBloom website
  static const Color rose = Color(0xFFC97B75);
  static const Color roseDeep = Color(0xFFB05A53);
  static const Color blush = Color(0xFFF9EDE8);
  static const Color teal = Color(0xFF5B9EA0);
  static const Color tealLight = Color(0xFFE8F4F5);
  static const Color cream = Color(0xFFF5F0EB);
  static const Color sage = Color(0xFF7A9E8E);
  static const Color gold = Color(0xFFD4A847);

  // Text
  static const Color textDark = Color(0xFF3D2B27);
  static const Color textMid = Color(0xFF5C4F4A);
  static const Color textLight = Color(0xFF9B8B86);

  // Background
  static const Color background = Color(0xFFFAF5F2);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.rose,
        secondary: AppColors.teal,
        surface: AppColors.white,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.textDark,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
          color: AppColors.textDark, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.playfairDisplay(
          color: AppColors.textDark, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.playfairDisplay(
          color: AppColors.textDark, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.playfairDisplay(
          color: AppColors.textDark, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.dmSans(
          color: AppColors.textDark, fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.dmSans(color: AppColors.textMid),
        bodyMedium: GoogleFonts.dmSans(color: AppColors.textMid),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: AppColors.textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rose,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.rose,
          side: const BorderSide(color: AppColors.rose, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLight.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textLight.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.dmSans(
          color: AppColors.textLight, fontSize: 14),
        labelStyle: GoogleFonts.dmSans(
          color: AppColors.textMid, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

class AppConstants {
  static late final String supabaseUrl;
  static late final String supabaseAnonKey;

  static void loadEnv() {
    supabaseUrl = dotenv.get('SUPABASE_URL', fallback: '');
    supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  }

  static const String appName = 'TinyBloom';
  static const String appTagline = 'Your Pregnancy Support Companion';
}
