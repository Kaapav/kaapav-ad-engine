import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════
// COLORS
// ═══════════════════════════════════════════════════════════
class C {
  // PRIMARY TURQUOISE
  static const primary = Color(0xFF00E5CC);
  static const primaryLight = Color(0xFF4DFFD9);
  static const primaryDark = Color(0xFF00B3A0);

  // BACKGROUNDS (layered dark)
  static const bgDeep = Color(0xFF020B14);
  static const bg = Color(0xFF041520);
  static const bgCard = Color(0xFF071E2E);
  static const bgLight = Color(0xFF0A2540);

  // GLASS
  static const glassWhite = Color(0x14FFFFFF);
  static const glassBorder = Color(0x33FFFFFF);
  static const glassTurq = Color(0x1A00E5CC);
  static const glassTurqBorder = Color(0x4D00E5CC);

  // TEXT
  static const textPrimary = Color(0xFFF0F8FF);
  static const textSecondary = Color(0xFF8BA8BF);
  static const textMuted = Color(0xFF4A6A85);

  // STATUS
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFB300);
  static const error = Color(0xFFFF1744);
  static const info = Color(0xFF00B0FF);
  static const learning = Color(0xFFFFA726);

  // ACCENTS
  static const blue = Color(0xFF0066FF);
  static const purple = Color(0xFF7B2FFF);
  static const pink = Color(0xFFFF2D92);
  static const gold = Color(0xFFFFD700);

  // PLATFORM
  static const facebook = Color(0xFF1877F2);
  static const instagram = Color(0xFFE1306C);
  static const whatsapp = Color(0xFF25D366);

  // GRADIENTS
  static const primaryGrad = LinearGradient(
    colors: [Color(0xFF00E5CC), Color(0xFF0066FF)],
  );
  static const bgGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDeep, bg, bgCard],
    stops: [0.0, 0.5, 1.0],
  );
  static const successGrad = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF00E5CC)],
  );
  static const dangerGrad = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFFF6B35)],
  );

  // CHART PALETTE
  static const chartColors = [
    primary, purple, blue, pink, gold, success, Color(0xFFFF6B35),
  ];
}

// ═══════════════════════════════════════════════════════════
// GLASS DECORATION HELPERS
// ═══════════════════════════════════════════════════════════
class Glass {
  static BoxDecoration card({
    double radius = 20,
    bool turquoise = false,
    bool glow = false,
    Color? glowColor,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: turquoise
            ? [C.glassTurq, C.glassTurq.withValues(alpha: 0.05)]
            : [C.glassWhite, C.glassWhite.withValues(alpha: 0.05)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: turquoise ? C.glassTurqBorder : C.glassBorder,
        width: 1,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: (glowColor ?? C.primary).withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
    );
  }

  static ImageFilter get blur => ImageFilter.blur(sigmaX: 15, sigmaY: 15);
  static ImageFilter get blurHeavy => ImageFilter.blur(sigmaX: 25, sigmaY: 25);
  static ImageFilter get blurLight => ImageFilter.blur(sigmaX: 8, sigmaY: 8);
}

// ═══════════════════════════════════════════════════════════
// APP THEME
// ═══════════════════════════════════════════════════════════
class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Sora',
        scaffoldBackgroundColor: C.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: C.primary,
          secondary: C.blue,
          surface: C.bgCard,
          error: C.error,
          onPrimary: Colors.black,
          onSurface: C.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: C.glassBorder,
          thickness: 0.5,
        ),
        splashColor: C.primary.withValues(alpha: 0.08),
        highlightColor: C.primary.withValues(alpha: 0.05),
      );
}