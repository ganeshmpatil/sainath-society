import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const primary = Color(0xFF7C3AED);
  static const secondary = Color(0xFF06B6D4);

  // Light theme colors (used directly in widgets)
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textTertiary = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFCBD5E1);

  // Status colors
  static const urgent = Color(0xFFEF4444);
  static const high = Color(0xFFF97316);
  static const medium = Color(0xFFEAB308);
  static const low = Color(0xFF10B981);
  static const open = Color(0xFF3B82F6);
  static const inProgress = Color(0xFF06B6D4);
  static const resolved = Color(0xFF10B981);
  static const closed = Color(0xFF64748B);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryGradientVertical = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Status background colors (with alpha)
  static final Color urgentBg = urgent.withAlpha(30);
  static final Color highBg = high.withAlpha(30);
  static final Color mediumBg = medium.withAlpha(30);
  static final Color lowBg = low.withAlpha(30);
  static final Color openBg = open.withAlpha(30);
  static final Color inProgressBg = inProgress.withAlpha(30);
  static final Color resolvedBg = resolved.withAlpha(30);
  static final Color closedBg = closed.withAlpha(30);
  static final Color primaryBg = primary.withAlpha(30);

  static Color priorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return urgent;
      case 'HIGH':
        return high;
      case 'MEDIUM':
        return medium;
      case 'LOW':
        return low;
      default:
        return textTertiary;
    }
  }

  static Color priorityBgColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return urgentBg;
      case 'HIGH':
        return highBg;
      case 'MEDIUM':
        return mediumBg;
      case 'LOW':
        return lowBg;
      default:
        return closedBg;
    }
  }

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return open;
      case 'IN_PROGRESS':
        return inProgress;
      case 'RESOLVED':
        return resolved;
      case 'CLOSED':
        return closed;
      case 'REJECTED':
        return urgent;
      case 'ACTIVE':
        return resolved;
      case 'DRAFT':
        return textTertiary;
      case 'PAID':
        return resolved;
      case 'OVERDUE':
        return urgent;
      case 'PENDING':
      case 'ISSUED':
        return medium;
      default:
        return textTertiary;
    }
  }

  static Color statusBgColor(String status) {
    return statusColor(status).withAlpha(30);
  }
}
