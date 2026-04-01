import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KaapavColors {
  static const Color kaapav50  = Color(0xFFFDF4F3);
  static const Color kaapav100 = Color(0xFFFCE8E4);
  static const Color kaapav200 = Color(0xFFFAD4CE);
  static const Color kaapav300 = Color(0xFFF5B5AB);
  static const Color kaapav400 = Color(0xFFED8B7A);
  static const Color kaapav500 = Color(0xFFE1654F);
  static const Color kaapav600 = Color(0xFFCD4832);
  static const Color kaapav700 = Color(0xFFAC3926);
  static const Color kaapav800 = Color(0xFF8E3223);
  static const Color kaapav900 = Color(0xFF772E23);

  static const Color dark50  = Color(0xFFF6F6F7);
  static const Color dark100 = Color(0xFFE2E3E5);
  static const Color dark200 = Color(0xFFC4C5CA);
  static const Color dark300 = Color(0xFF9FA1A8);
  static const Color dark400 = Color(0xFF7B7D85);
  static const Color dark500 = Color(0xFF61636B);
  static const Color dark600 = Color(0xFF4D4E55);
  static const Color dark700 = Color(0xFF3F4046);
  static const Color dark800 = Color(0xFF27272A);
  static const Color dark900 = Color(0xFF18181B);
  static const Color dark950 = Color(0xFF0F0F12);

  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error   = Color(0xFFF87171);
  static const Color info    = Color(0xFF60A5FA);

  static const Color glassBg       = Color(0x1AFFFFFF);
  static const Color glassBgHover  = Color(0x2AFFFFFF);
  static const Color glassBorder   = Color(0x1AFFFFFF);
  static const Color glassBorderHi = Color(0x33FFFFFF);

  static const Color glowPurple = Color(0x338B5CF6);
  static const Color glowCyan   = Color(0x3306B6D4);

  static const LinearGradient meshGradient1 = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F0F12), Color(0xFF1A0D1F), Color(0xFF0F0F12), Color(0xFF0D1520), Color(0xFF0F0F12)],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
  );

  static const LinearGradient glassBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FFFFFF), Color(0x0DFFFFFF), Color(0x00FFFFFF), Color(0x0DFFFFFF)],
    stops: [0.0, 0.3, 0.6, 1.0],
  );
}

class GlassBlur {
  static const double subtle = 10.0;
  static const double medium = 20.0;
  static const double strong = 40.0;
}

class KaapavTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: KaapavColors.dark950,
      colorScheme: ColorScheme.dark(
        primary: KaapavColors.kaapav600,
        secondary: KaapavColors.kaapav400,
        surface: KaapavColors.dark900,
        error: KaapavColors.error,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: KaapavColors.dark100,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KaapavColors.glassBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: KaapavColors.glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: KaapavColors.glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: KaapavColors.kaapav500, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: KaapavColors.dark400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KaapavColors.kaapav600,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(color: KaapavColors.glassBorder, thickness: 1),
    );
  }
}
