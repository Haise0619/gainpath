import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// Coloured status pill.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  const StatusChip(this.label,
      {super.key, this.color = AppColors.primary, this.background = AppColors.primaryTint});


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

Widget statusPill(String status) {
  Color fg;
  Color bg;
  switch (status.toLowerCase()) {
    case 'confirmed':
    case 'active':
    case 'verified':
    case 'cleared':
    case 'completed':
      fg = AppColors.success;
      bg = AppColors.primaryTint;
      break;
    case 'pending':
    case 'pending review':
    case 'invited':
      fg = AppColors.warning;
      bg = AppColors.accentTint;
      break;
    case 'suspended':
    case 'cancelled':
    case 'rejected':
    case 'deactivated':
    case 'high':
      fg = AppColors.danger;
      bg = AppColors.dangerTint;
      break;
    default:
      fg = AppColors.inkSoft;
      bg = AppColors.surfaceAlt;
  }
  return StatusChip(status, color: fg, background: bg);
}
