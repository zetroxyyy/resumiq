import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for saving theme preference
const String _themePrefsKey = 'theme_mode_preference';

// Riverpod provider for ThemeMode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLight = prefs.getBool(_themePrefsKey) ?? false;
      state = isLight ? ThemeMode.light : ThemeMode.dark;
    } catch (_) {
      // Fallback to default dark
      state = ThemeMode.dark;
    }
  }

  Future<void> toggleTheme() async {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = nextMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefsKey, nextMode == ThemeMode.light);
    } catch (_) {}
  }
}

class AppTheme {
  AppTheme._();

  // Custom Colors
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color errorColor = Color(0xFFCF6679);
  static const Color proBadgeColor = Color(0xFFFFD700);

  // Dark Colors
  static const Color darkBg = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);

  // Light Colors
  static const Color lightBg = Color(0xFFF8F9FF);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Dark Theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: darkSurface,
      ),
      scaffoldBackgroundColor: darkBg,
      cardColor: darkSurface,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // Light Theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: lightSurface,
      ),
      scaffoldBackgroundColor: lightBg,
      cardColor: lightSurface,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final baseTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    return TextTheme(
      displayLarge: GoogleFonts.poppins(
        textStyle: baseTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      displayMedium: GoogleFonts.poppins(
        textStyle: baseTextTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      displaySmall: GoogleFonts.poppins(
        textStyle: baseTextTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      headlineLarge: GoogleFonts.poppins(
        textStyle: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      headlineMedium: GoogleFonts.poppins(
        textStyle: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      headlineSmall: GoogleFonts.poppins(
        textStyle: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      titleLarge: GoogleFonts.poppins(
        textStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      titleMedium: GoogleFonts.poppins(
        textStyle: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      titleSmall: GoogleFonts.poppins(
        textStyle: baseTextTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      bodyLarge: GoogleFonts.inter(textStyle: baseTextTheme.bodyLarge),
      bodyMedium: GoogleFonts.inter(textStyle: baseTextTheme.bodyMedium),
      bodySmall: GoogleFonts.inter(textStyle: baseTextTheme.bodySmall),
      labelLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      labelMedium: GoogleFonts.inter(textStyle: baseTextTheme.labelMedium),
      labelSmall: GoogleFonts.inter(textStyle: baseTextTheme.labelSmall),
    );
  }
}
