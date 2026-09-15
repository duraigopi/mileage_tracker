import 'package:flutter/material.dart';

/// Theme-aware colors that adapt to light/dark mode
class AppColors {
  final BuildContext _context;
  AppColors.of(this._context);

  bool get _isDark => Theme.of(_context).brightness == Brightness.dark;

  // Card & surface backgrounds
  Color get card => _isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get surface => _isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50;
  Color get surfaceLight => _isDark ? const Color(0xFF333333) : Colors.grey.shade100;

  // Text colors
  Color get textPrimary => _isDark ? Colors.white : Colors.grey.shade800;
  Color get textSecondary => _isDark ? Colors.grey.shade300 : Colors.grey.shade600;
  Color get textTertiary => _isDark ? Colors.grey.shade500 : Colors.grey.shade400;
  Color get textHint => _isDark ? Colors.grey.shade600 : Colors.grey.shade400;

  // Borders & dividers
  Color get border => _isDark ? Colors.grey.shade700 : Colors.grey.shade200;
  Color get divider => _isDark ? Colors.grey.shade700 : Colors.grey.shade100;

  // Shadows (no shadow in dark mode)
  List<BoxShadow> get cardShadow => _isDark
      ? []
      : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))];

  // Chart grid
  Color get chartGrid => _isDark ? Colors.grey.shade800 : Colors.grey.shade100;

  // Close button
  Color get closeButtonBg => _isDark ? Colors.grey.shade800 : Colors.grey.shade100;
  Color get closeButtonIcon => _isDark ? Colors.grey.shade300 : Colors.grey.shade500;

  // Progress bar background
  Color get progressBg => _isDark ? Colors.grey.shade800 : Colors.grey.shade100;

  // Autocomplete dropdown
  Color get dropdownBg => _isDark ? const Color(0xFF2C2C2C) : Colors.white;

  // Category chip unselected
  Color get chipBg => _isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade50;
  Color get chipBorder => _isDark ? Colors.grey.shade600 : Colors.grey.shade200;

  // Service reminder
  Color get reminderBg => _isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0);
  Color get reminderBorder => _isDark ? const Color(0xFFE65100) : const Color(0xFFFFCC02);

  // Fuel quantity card
  Color get fuelCalcBg => _isDark ? const Color(0xFF1B3A1B) : const Color(0xFFF1F8E9);
  Color get fuelCalcBorder => _isDark ? const Color(0xFF388E3C) : const Color(0xFFC5E1A5);

  // Error card
  Color get errorBg => _isDark ? const Color(0xFF3E1111) : Colors.red.shade50;
  Color get errorBorder => _isDark ? Colors.red.shade700 : Colors.red.shade200;

  // Full reading card
  Color get successBg => _isDark ? const Color(0xFF1B3A1B) : const Color(0xFFE8F5E9);
  Color get successBorder => _isDark ? const Color(0xFF388E3C) : const Color(0xFFA5D6A7);

  // Fuel total cost card
  Color get fuelCostBg => _isDark ? const Color(0xFF3E2C1B) : const Color(0xFFFFF3E0);
}
