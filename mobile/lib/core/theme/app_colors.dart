import 'package:flutter/material.dart';

enum AppThemeType { royalGold, oceanBlue, freshEmerald }

class AppColors {
  static AppThemeType _current = AppThemeType.royalGold;
  static AppThemeType get current => _current;

  // ── Theme-aware colors (set by applyTheme) ──
  static Color primary = const Color(0xFFD4AF37);
  static Color secondary = const Color(0xFFF4D03F);
  static Color surface = const Color(0xFF1A1028);
  static Color background = const Color(0xFF0C0C1D);
  static Color textPrimary = const Color(0xFFFFFFFF);
  static Color textSecondary = const Color(0x80FFFFFF);
  static Color textTertiary = const Color(0x4DFFFFFF);
  static Color border = const Color(0x26D4AF37);
  static Color borderLight = const Color(0x14D4AF37);

  static LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFF4D03F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient primaryGradientVertical = const LinearGradient(
    colors: [Color(0xFFD4AF37), Color(0xFFF4D03F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Status colors (constant across all themes) ──
  static const urgent = Color(0xFFEF4444);
  static const high = Color(0xFFF97316);
  static const medium = Color(0xFFEAB308);
  static const low = Color(0xFF10B981);
  static const open = Color(0xFF3B82F6);
  static const inProgress = Color(0xFF06B6D4);
  static const resolved = Color(0xFF10B981);
  static const closed = Color(0xFF64748B);

  // Status backgrounds
  static final Color urgentBg = urgent.withAlpha(30);
  static final Color highBg = high.withAlpha(30);
  static final Color mediumBg = medium.withAlpha(30);
  static final Color lowBg = low.withAlpha(30);
  static final Color openBg = open.withAlpha(30);
  static final Color inProgressBg = inProgress.withAlpha(30);
  static final Color resolvedBg = resolved.withAlpha(30);
  static final Color closedBg = closed.withAlpha(30);
  static Color primaryBg = const Color(0xFFD4AF37).withAlpha(30);

  /// Apply a named theme. Call from the top-level build.
  static void applyTheme(AppThemeType type) {
    _current = type;
    switch (type) {
      case AppThemeType.royalGold:
        primary = const Color(0xFFD4AF37);
        secondary = const Color(0xFFF4D03F);
        surface = const Color(0xFF1A1028);
        background = const Color(0xFF0C0C1D);
        textPrimary = const Color(0xFFFFFFFF);
        textSecondary = const Color(0x80FFFFFF);
        textTertiary = const Color(0x4DFFFFFF);
        border = const Color(0x26D4AF37);
        borderLight = const Color(0x14D4AF37);
        primaryGradient = const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFF4D03F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        );
        primaryGradientVertical = const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFF4D03F)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        );

      case AppThemeType.oceanBlue:
        primary = const Color(0xFF38BDF8);
        secondary = const Color(0xFF6366F1);
        surface = const Color(0xFF0A1628);
        background = const Color(0xFF050D1A);
        textPrimary = const Color(0xFFFFFFFF);
        textSecondary = const Color(0x80FFFFFF);
        textTertiary = const Color(0x4DFFFFFF);
        border = const Color(0x1F38BDF8);
        borderLight = const Color(0x0F38BDF8);
        primaryGradient = const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        );
        primaryGradientVertical = const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        );

      case AppThemeType.freshEmerald:
        primary = const Color(0xFF059669);
        secondary = const Color(0xFF10B981);
        surface = const Color(0xFFFFFFFF);
        background = const Color(0xFFF8FAFC);
        textPrimary = const Color(0xFF0F172A);
        textSecondary = const Color(0xFF475569);
        textTertiary = const Color(0xFF94A3B8);
        border = const Color(0xFFE2E8F0);
        borderLight = const Color(0xFFF1F5F9);
        primaryGradient = const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        );
        primaryGradientVertical = const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        );
    }
    primaryBg = primary.withAlpha(30);
  }

  static bool get isDark => _current != AppThemeType.freshEmerald;

  static Color priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT': return urgent;
      case 'HIGH': return high;
      case 'MEDIUM': return medium;
      case 'LOW': return low;
      default: return textTertiary;
    }
  }

  static Color priorityBgColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT': return urgentBg;
      case 'HIGH': return highBg;
      case 'MEDIUM': return mediumBg;
      case 'LOW': return lowBg;
      default: return closedBg;
    }
  }

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN': return open;
      case 'IN_PROGRESS': return inProgress;
      case 'RESOLVED': return resolved;
      case 'CLOSED': return closed;
      case 'REJECTED': return urgent;
      case 'ACTIVE': return resolved;
      case 'DRAFT': return textTertiary;
      case 'PAID': return resolved;
      case 'OVERDUE': return urgent;
      case 'PENDING':
      case 'ISSUED': return medium;
      default: return textTertiary;
    }
  }

  static Color statusBgColor(String status) {
    return statusColor(status).withAlpha(30);
  }
}
