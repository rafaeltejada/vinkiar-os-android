import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VinkiarColors {
  static const Color abyssBlack = Color(0xFF050505);
  static const Color inkBlack = Color(0xFF111111);
  static const Color panelDark = Color(0xFF18181C);

  static const Color aegisCyan = Color(0xFF00FFCC);
  static const Color vertigoGold = Color(0xFFFFCC00);
  static const Color lotusPink = Color(0xFFFF007F);
  static const Color mysteryMagenta = Color(0xFFFF00FF);
  
  static const Color panicRed = Color(0xFFFF3300);
  static const Color hackingGreen = Color(0xFF39FF14);
  
  static const Color textHdr = Color(0xFFF0F0F0);
  static const Color textDim = Color(0xFF888888);

  // Glow shadows
  static List<BoxShadow> cyanGlow({double opacity = 0.5, double blur = 10.0}) => [
    BoxShadow(
      color: aegisCyan.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: 1,
    )
  ];

  static List<BoxShadow> redGlow({double opacity = 0.6, double blur = 15.0}) => [
    BoxShadow(
      color: panicRed.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: 1,
    )
  ];
}

class VinkiarTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: VinkiarColors.aegisCyan,
      scaffoldBackgroundColor: VinkiarColors.abyssBlack,
      cardColor: VinkiarColors.panelDark,
      hintColor: VinkiarColors.textDim,
      colorScheme: const ColorScheme.dark(
        primary: VinkiarColors.aegisCyan,
        secondary: VinkiarColors.lotusPink,
        tertiary: VinkiarColors.vertigoGold,
        error: VinkiarColors.panicRed,
        background: VinkiarColors.abyssBlack,
        surface: VinkiarColors.inkBlack,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          color: VinkiarColors.textHdr,
          fontSize: 48,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.02,
        ),
        headlineLarge: GoogleFonts.outfit(
          color: VinkiarColors.textHdr,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: GoogleFonts.outfit(
          color: VinkiarColors.textHdr,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: VinkiarColors.textHdr,
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: VinkiarColors.textHdr,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  static TextStyle get terminalData => GoogleFonts.jetBrainsMono(
    color: VinkiarColors.aegisCyan,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05,
  );

  static TextStyle get terminalSm => GoogleFonts.jetBrainsMono(
    color: VinkiarColors.textDim,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get labelCaps => GoogleFonts.jetBrainsMono(
    color: VinkiarColors.aegisCyan,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.1,
  );
}
