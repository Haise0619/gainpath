import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';

/// Square icon-and-label chip that toggles selected/unselected, used for
/// multi-select choices such as training motivations.
class ToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ToggleChip({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.hairline, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: selected ? AppColors.primary : AppColors.inkSoft, size: 22),
                if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
              ],
            ),
            const Spacer(),
            Text(label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.ink,
                  height: 1.2,
                )),
          ],
        ),
      ),
    );
  }
}
