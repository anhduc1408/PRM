import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Mixue Red
  static const Color primary = Color(0xFFE30613);
  static const Color primaryDark = Color(0xFFB00000);
  static const Color primaryLight = Color(0xFFFF4D4D);

  // Secondary
  static const Color secondary = Color(0xFFFFD700);
  static const Color secondaryLight = Color(0xFFFFF3CD);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFADB5BD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Chart colors
  static const List<Color> chartColors = [
    Color(0xFFE30613),
    Color(0xFFFFD700),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
  ];

  // Role colors
  static const Color ceoColor = Color(0xFF1A1A2E);
  static const Color itColor = Color(0xFF3B82F6);
  static const Color staffColor = Color(0xFF10B981);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE30613), Color(0xFFB00000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Divider
  static const Color divider = Color(0xFFE9ECEF);
  static const Color border = Color(0xFFDEE2E6);
}
