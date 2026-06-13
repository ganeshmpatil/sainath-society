import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  factory StatusBadge.priority(String priority) {
    return StatusBadge(
      label: priority,
      color: AppColors.priorityColor(priority),
      backgroundColor: AppColors.priorityBgColor(priority),
    );
  }

  factory StatusBadge.status(String status) {
    return StatusBadge(
      label: status.replaceAll('_', ' '),
      color: AppColors.statusColor(status),
      backgroundColor: AppColors.statusBgColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
