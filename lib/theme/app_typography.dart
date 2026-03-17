import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const String fontFamily = 'Outfit';
  static const String displayFamily = 'Playfair';

  // ── Display Styles (Playfair) ──────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: displayFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: displayFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  // ── Headline Styles (Outfit) ───────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  // ── Title Styles ───────────────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ── Body Styles ────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.5,
  );

  // ── Label Styles ───────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ── Special Styles ─────────────────────────────────────────
  static const TextStyle statNumber = TextStyle(
    fontFamily: displayFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1,
  );

  // ── Heading Aliases ────────────────────────────────────────
  static const TextStyle headingLarge = headlineLarge;
  static const TextStyle headingMedium = headlineMedium;
  static const TextStyle headingSmall = headlineSmall;

  // ── Font Family Constants ──────────────────────────────────
  static const String displayFont = displayFamily;

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.4,
    color: AppColors.lightTextSecondary,
  );

  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1,
  );

  // ── Text Theme ─────────────────────────────────────────────
  static TextTheme get lightTextTheme => TextTheme(
    displayLarge: displayLarge.copyWith(color: AppColors.lightTextPrimary),
    displayMedium: displayMedium.copyWith(color: AppColors.lightTextPrimary),
    displaySmall: displaySmall.copyWith(color: AppColors.lightTextPrimary),
    headlineLarge: headlineLarge.copyWith(color: AppColors.lightTextPrimary),
    headlineMedium: headlineMedium.copyWith(color: AppColors.lightTextPrimary),
    headlineSmall: headlineSmall.copyWith(color: AppColors.lightTextPrimary),
    titleLarge: titleLarge.copyWith(color: AppColors.lightTextPrimary),
    titleMedium: titleMedium.copyWith(color: AppColors.lightTextSecondary),
    titleSmall: titleSmall.copyWith(color: AppColors.lightTextSecondary),
    bodyLarge: bodyLarge.copyWith(color: AppColors.lightTextPrimary),
    bodyMedium: bodyMedium.copyWith(color: AppColors.lightTextSecondary),
    bodySmall: bodySmall.copyWith(color: AppColors.lightTextHint),
    labelLarge: labelLarge.copyWith(color: AppColors.lightTextPrimary),
    labelMedium: labelMedium.copyWith(color: AppColors.lightTextSecondary),
    labelSmall: labelSmall.copyWith(color: AppColors.lightTextHint),
  );

  static TextTheme get darkTextTheme => TextTheme(
    displayLarge: displayLarge.copyWith(color: AppColors.darkTextPrimary),
    displayMedium: displayMedium.copyWith(color: AppColors.darkTextPrimary),
    displaySmall: displaySmall.copyWith(color: AppColors.darkTextPrimary),
    headlineLarge: headlineLarge.copyWith(color: AppColors.darkTextPrimary),
    headlineMedium: headlineMedium.copyWith(color: AppColors.darkTextPrimary),
    headlineSmall: headlineSmall.copyWith(color: AppColors.darkTextPrimary),
    titleLarge: titleLarge.copyWith(color: AppColors.darkTextPrimary),
    titleMedium: titleMedium.copyWith(color: AppColors.darkTextSecondary),
    titleSmall: titleSmall.copyWith(color: AppColors.darkTextSecondary),
    bodyLarge: bodyLarge.copyWith(color: AppColors.darkTextPrimary),
    bodyMedium: bodyMedium.copyWith(color: AppColors.darkTextSecondary),
    bodySmall: bodySmall.copyWith(color: AppColors.darkTextHint),
    labelLarge: labelLarge.copyWith(color: AppColors.darkTextPrimary),
    labelMedium: labelMedium.copyWith(color: AppColors.darkTextSecondary),
    labelSmall: labelSmall.copyWith(color: AppColors.darkTextHint),
  );
}
