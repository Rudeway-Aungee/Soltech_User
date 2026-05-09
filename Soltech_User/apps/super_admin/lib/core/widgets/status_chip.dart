import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
  });

  final String status;

  Color get color {
    final lower = status.toLowerCase();

    if (lower == 'approved' ||
        lower == 'active' ||
        lower == 'completed' ||
        lower == 'resolved') {
      return AppColors.primary;
    }

    if (lower == 'rejected' || lower == 'cancelled') {
      return AppColors.danger;
    }

    if (lower == 'pending' ||
        lower == 'searching' ||
        lower == 'in_progress') {
      return AppColors.warning;
    }

    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.25)),
    );
  }
}