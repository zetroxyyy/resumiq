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
  static const Color accentGoldLight = Color(0xFFB8935B);
  static const Color accentGoldDark = Color(0xFFC9A876);
  static const Color accentPressedLight = Color(0xFFA17F49);
  static const Color accentPressedDark = Color(0xFFB8935B);

  // Dark Colors
  static const Color darkBg = Color(0xFF14141C);
  static const Color darkSurface = Color(0xFF1E1E28);
  static const Color darkDivider = Color(0xFF2A2A36);
  static const Color darkTextPrimary = Color(0xFFF2F0EA);
  static const Color darkTextSecondary = Color(0xFFA8A6B0);

  // Light Colors
  static const Color lightBg = Color(0xFFFAF8F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE4E1D8);
  static const Color lightTextPrimary = Color(0xFF14141C);
  static const Color lightTextSecondary = Color(0xFF6B6B76);

  // Dark Theme configuration
  static ThemeData get darkTheme {
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
      textTheme: _buildTextTheme(Brightness.dark),
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

  // Light Theme configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: accentGoldLight,
        primaryContainer: accentPressedLight,
        secondary: lightTextSecondary,
        surface: lightSurface,
        background: lightBg,
        error: Color(0xFFB5544A),
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
        outline: lightDivider,
      ),
      scaffoldBackgroundColor: lightBg,
      cardColor: lightSurface,
      dividerColor: lightDivider,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(color: lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
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

  static TextTheme _buildTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryTextColor = isDark ? darkTextPrimary : lightTextPrimary;
    final secondaryTextColor = isDark ? darkTextSecondary : lightTextSecondary;

    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

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
