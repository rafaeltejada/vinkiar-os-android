import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VinkiarTheme {
  // Paleta de Colores Cyber-Noir
  static const Color bgDark = Color(0xFF090B10);
  static const Color bgPanel = Color(0xFF121620);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonMagenta = Color(0xFFFF007F);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textMuted = Color(0xFF6C7A89);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: neonCyan,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonMagenta,
        surface: bgPanel,
        background: bgDark,
        error: neonMagenta,
      ),
      // Tipografía de Terminal
      textTheme: GoogleFonts.shareTechMonoTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: neonCyan,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: neonCyan),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonCyan.withOpacity(0.1),
          foregroundColor: neonCyan,
          side: const BorderSide(color: neonCyan, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      cardTheme: CardThemeData(
        color: bgPanel,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: neonCyan.withOpacity(0.2), width: 1),
        ),
      ),
    );
  }
}
