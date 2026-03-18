import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Primary — Deep Navy Blue ───
  static const Color primary = Color(0xFF0A1628);
  static const Color primaryLight = Color(0xFF162844);
  static const Color primaryDark = Color(0xFF060E1A);

  // ─── Accent — Gold ───
  static const Color accent = Color(0xFFD4A843);
  static const Color accentLight = Color(0xFFE8C875);
  static const Color accentDark = Color(0xFFB8882A);

  // ─── Secondary — Steel Blue ───
  static const Color secondary = Color(0xFF1E3A5F);
  static const Color secondaryLight = Color(0xFF2D5490);

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF2ECC71);
  static const Color successLight = Color(0xFFD5F5E3);
  static const Color warning = Color(0xFFF39C12);
  static const Color warningLight = Color(0xFFFEF9E7);
  static const Color error = Color(0xFFE74C3C);
  static const Color errorLight = Color(0xFFFDEDEC);
  static const Color info = Color(0xFF3498DB);
  static const Color infoLight = Color(0xFFEBF5FB);

  // ─── Attendance Status ───
  static const Color present = Color(0xFF2ECC71);
  static const Color absent = Color(0xFFE74C3C);
  static const Color late = Color(0xFFF39C12);

  // ─── Light Theme Neutrals ───
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8ECF0);
  static const Color lightDivider = Color(0xFFEEF1F5);
  static const Color lightText = Color(0xFF0A1628);
  static const Color lightTextSecondary = Color(0xFF6B7A99);
  static const Color lightTextHint = Color(0xFFADB5C7);

  // ─── Dark Theme Neutrals ───
  static const Color darkBackground = Color(0xFF060E1A);
  static const Color darkSurface = Color(0xFF0D1E35);
  static const Color darkCard = Color(0xFF132442);
  static const Color darkBorder = Color(0xFF1E3A5F);
  static const Color darkDivider = Color(0xFF162844);
  static const Color darkText = Color(0xFFF0F4FF);
  static const Color darkTextSecondary = Color(0xFF8FA3C0);
  static const Color darkTextHint = Color(0xFF4A6080);

  // ─── Role Colors ───
  static const Color adminColor = Color(0xFFD4A843);
  static const Color teacherColor = Color(0xFF3498DB);
  static const Color studentColor = Color(0xFF2ECC71);

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentDark, accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E3A5F), Color(0xFF0A1628)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
