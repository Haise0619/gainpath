import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// 0 (empty) to 3 (strong). Shared by every "set a password" surface so the
/// bar and its thresholds always mean the same thing.
int passwordStrengthOf(String password) {
  if (password.isEmpty) return 0;
  var score = 0;
  if (password.length >= 8) score++;
  if (RegExp(r'[0-9]').hasMatch(password) && RegExp(r'[A-Za-z]').hasMatch(password)) score++;
  if (password.length >= 12 || RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password)) score++;
  return score;
}

class PasswordStrengthMeter extends StatelessWidget {
  final int strength;
  const PasswordStrengthMeter({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    const labels = ['Too short', 'Weak', 'Good', 'Strong'];
    const colors = [AppColors.danger, AppColors.danger, AppColors.warning, AppColors.success];
    final label = labels[strength];
    final color = colors[strength];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < strength;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                decoration: BoxDecoration(
                  color: filled ? color : AppColors.hairline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
