import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0F1B1E);
  static const card = Color(0xFF172A2E);
  static const border = Color(0xFF24383C);
  static const accent = Color(0xFFE8B26A);
  static const muted = Color(0xFF9FB3AD);
  static const good = Color(0xFF8FD6A8);
}

final appTheme = ThemeData(
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: AppColors.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF3A5256)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.card,
  ),
  cardTheme: CardThemeData(
    color: AppColors.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg),
);