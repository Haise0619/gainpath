import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(999)),
          ),
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(ctx).textTheme.bodyLarge),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: destructive
                      ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                      : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(confirmLabel, maxLines: 1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Not now', maxLines: 1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
