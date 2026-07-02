import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF57068C);
  static const primaryLight = Color(0xFFEDE9FE);
  static const primaryAlpha15 = Color(0x2657068C);

  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF8F9FA);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);

  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);

  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF9C3);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEF2F2);

  static const classRed = Color(0xFFFF5F5F);
  static const studyGreen = Color(0xFF34C759);

  static const List<List<Color>> avatarPalette = [
    [Color(0xFFE0F2FE), Color(0xFF0369A1)],
    [Color(0xFFFFEDD5), Color(0xFFC2410C)],
    [Color(0xFFDCFCE7), Color(0xFF15803D)],
    [Color(0xFFF3E8FF), Color(0xFF7E22CE)],
    [Color(0xFFFFF7ED), Color(0xFF92400E)],
  ];
}

class AppText {
  AppText._();

  static const displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const headingLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const headingMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const headingSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const bodySmall = TextStyle(
    fontSize: 13,
    color: AppColors.textMuted,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.textMuted,
  );

  static const sidebarItem = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const sidebarItemActive = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}
