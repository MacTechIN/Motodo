import 'package:flutter/material.dart';

class AppColors {
  // Pastel Palette for Priorities
  static const Color priority1 = Color(0xFFE8F5E9); // Soft Mint (Level 1)
  static const Color priority2 = Color(0xFFE3F2FD); // Sky Blue (Level 2)
  static const Color priority3 = Color(0xFFFFFDE7); // Pale Yellow (Level 3)
  static const Color priority4 = Color(0xFFFFF3E0); // Peach Orange (Level 4)
  static const Color priority5 = Color(0xFFFCE4EC); // Dusty Rose (Level 5)

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
}

class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle subHeading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
}

Color getPriorityColor(int priority) {
  switch (priority) {
    case 1: return AppColors.priority1;
    case 2: return AppColors.priority2;
    case 3: return AppColors.priority3;
    case 4: return AppColors.priority4;
    case 5: return AppColors.priority5;
    default: return Colors.grey.shade200;
  }
}
