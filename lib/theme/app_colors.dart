import 'package:flutter/material.dart';

class AppColors {
  // ── Brand Palette ──────────────────────────────────────────
  static const Color primary = Color(0xFF1A1F71); // Deep Navy Blue
  static const Color primaryLight = Color(0xFF2D3561);
  static const Color primaryDark = Color(0xFF0D1045);

  static const Color accent = Color(0xFFD4AF37); // Royal Gold
  static const Color accentLight = Color(0xFFE8CB5A);
  static const Color accentDark = Color(0xFFB8960C);

  static const Color secondary = Color(0xFF00B4D8); // Electric Cyan
  static const Color secondaryLight = Color(0xFF48CAE4);
  static const Color secondaryDark = Color(0xFF0096C7);

  // ── Status Colors ──────────────────────────────────────────
  static const Color success = Color(0xFF2DC653);
  static const Color successLight = Color(0xFFE8F8ED);
  static const Color warning = Color(0xFFFFB703);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFE63946);
  static const Color errorLight = Color(0xFFFFEBEC);
  static const Color info = Color(0xFF4361EE);
  static const Color infoLight = Color(0xFFEEF1FF);

  // ── Attendance Status ──────────────────────────────────────
  static const Color present = Color(0xFF2DC653);
  static const Color absent = Color(0xFFE63946);
  static const Color late = Color(0xFFFFB703);

  // ── Light Theme ────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF0F8);
  static const Color lightBorder = Color(0xFFE0E3F0);
  static const Color lightTextPrimary = Color(0xFF1A1F71);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextHint = Color(0xFFADB5BD);
  static const Color lightDivider = Color(0xFFEEF0F8);
  static const Color lightCardShadow = Color(0x1A1A1F71);

  // ── Dark Theme ─────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0D0F1E);
  static const Color darkSurface = Color(0xFF161929);
  static const Color darkSurfaceVariant = Color(0xFF1E2235);
  static const Color darkBorder = Color(0xFF2A2F4A);
  static const Color darkTextPrimary = Color(0xFFF0F2FF);
  static const Color darkTextSecondary = Color(0xFF9BA3C0);
  static const Color darkTextHint = Color(0xFF5C6480);
  static const Color darkDivider = Color(0xFF1E2235);
  static const Color darkCardShadow = Color(0x40000000);

  // ── Role Colors ────────────────────────────────────────────
  static const Color adminColor = Color(0xFF1A1F71);
  static const Color teacherColor = Color(0xFF0096C7);
  static const Color studentColor = Color(0xFF2DC653);

  // ── Card Colors ───────────────────────────────────────────
  static const Color lightCard = lightSurface;
  static const Color darkCard = darkSurface;

  // ── Text Colors ───────────────────────────────────────────
  static const Color lightText = lightTextPrimary;
  static const Color darkText = darkTextPrimary;

  // ── Gradient Definitions ───────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentDark, accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryDark, primary, Color(0xFF2D3561)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1F71), Color(0xFF2D3561)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF2DC653), Color(0xFF1AAD3F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB703), Color(0xFFFF9500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFE63946), Color(0xFFC1121F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
