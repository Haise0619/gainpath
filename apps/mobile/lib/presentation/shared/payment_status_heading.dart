import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

enum PaymentStage { loading, pending, success, failure }

class PaymentStatusHeading extends StatelessWidget {
  const PaymentStatusHeading(
      {super.key, required this.stage, required this.title});
  final PaymentStage stage;
  final String title;

  @override
  Widget build(BuildContext context) => Column(children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.primaryTint,
          child: stage == PaymentStage.loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary))
              : Icon(
                  switch (stage) {
                    PaymentStage.success => Icons.check_rounded,
                    PaymentStage.failure => Icons.error_outline_rounded,
                    _ => Icons.schedule_rounded,
                  },
                  color: AppColors.primary,
                  size: 30),
        ),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
      ]);
}
