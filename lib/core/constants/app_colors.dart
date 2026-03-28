import 'package:flutter/material.dart';

// WHY: Centralised palette prevents color drift across screens.
// Every color is referenced by semantic name — never raw hex in widgets.
class AppColors {
  AppColors._();

  // ── Brand ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  // ── Attendance Status ─────────────────────────────────────────────
  static const Color present = Color(0xFF22C55E);
  static const Color wfh = Color(0xFFEAB308);
  static const Color halfDay = Color(0xFFF97316);
  static const Color absent = Color(0xFFEF4444);
  static const Color late = Color(0xFFF59E0B);

  // ── Surfaces ──────────────────────────────────────────────────────
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF334155);

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // ── Borders ───────────────────────────────────────────────────────
  static const Color divider = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF475569);

  // ── Semantic ──────────────────────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF0284C7);

  // ── Gradients ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
