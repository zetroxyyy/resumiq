import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Custom Colors
  static const Color accentGoldDark = Color(0xFFC9A876);
  static const Color accentPressedDark = Color(0xFFB8935B);

  // Dark Colors
  static const Color darkBg = Color(0xFF14141C);
  static const Color darkSurface = Color(0xFF1E1E28);
  static const Color darkDivider = Color(0xFF2A2A36);
  static const Color darkTextPrimary = Color(0xFFF2F0EA);
  static const Color darkTextSecondary = Color(0xFFA8A6B0);

  // Theme configuration (Dark theme only)
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accentGoldDark,
        primaryContainer: accentPressedDark,
        secondary: darkTextSecondary,
        surface: darkSurface,
        background: darkBg,
        error: Color(0xFFC5645A),
        onPrimary: darkBg,
        onSurface: darkTextPrimary,
        outline: darkDivider,
      ),
      scaffoldBackgroundColor: darkBg,
      cardColor: darkSurface,
      dividerColor: darkDivider,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    final primaryTextColor = darkTextPrimary;
    final secondaryTextColor = darkTextSecondary;

    final baseTextTheme = ThemeData.dark().textTheme;

    return TextTheme(
      displayLarge: GoogleFonts.fraunces(
        textStyle: baseTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      displayMedium: GoogleFonts.fraunces(
        textStyle: baseTextTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      displaySmall: GoogleFonts.fraunces(
        textStyle: baseTextTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      headlineLarge: GoogleFonts.fraunces(
        textStyle: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      headlineMedium: GoogleFonts.fraunces(
        textStyle: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      headlineSmall: GoogleFonts.fraunces(
        textStyle: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      titleLarge: GoogleFonts.fraunces(
        textStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      titleMedium: GoogleFonts.fraunces(
        textStyle: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      titleSmall: GoogleFonts.fraunces(
        textStyle: baseTextTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyLarge?.copyWith(
          color: primaryTextColor,
        ),
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyMedium?.copyWith(
          color: primaryTextColor,
        ),
      ),
      bodySmall: GoogleFonts.inter(
        textStyle: baseTextTheme.bodySmall?.copyWith(
          color: secondaryTextColor,
        ),
      ),
      labelLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryTextColor,
        ),
      ),
      labelMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.labelMedium?.copyWith(
          color: secondaryTextColor,
        ),
      ),
      labelSmall: GoogleFonts.inter(
        textStyle: baseTextTheme.labelSmall?.copyWith(
          color: secondaryTextColor,
        ),
      ),
    );
  }
}
