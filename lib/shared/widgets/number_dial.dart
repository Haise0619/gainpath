import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/shared/widgets/panel.dart';

/// Stepper-and-slider numeric picker used for age, height, and weight,
/// during onboarding and again whenever those fields are edited later.
class NumberDial extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final String suffix;
  final String display;
  final String captionUnit;
  final ValueChanged<double> onChanged;

  const NumberDial({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.display,
    required this.captionUnit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _stepper(Icons.remove_rounded, () => onChanged((value - 1).clamp(min, max))),
              SizedBox(
                width: 150,
                child: Column(
                  children: [
                    Text(
                      '$display$suffix',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    Text(captionUnit, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              _stepper(Icons.add_rounded, () => onChanged((value + 1).clamp(min, max))),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.hairline,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton.filled(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceAlt,
          foregroundColor: AppColors.ink,
        ),
        icon: Icon(icon, size: 20),
      ),
    );
  }
}
