import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Every modal action anywhere in the admin web console — confirm, edit,
/// provision, publish — opens through one of the primitives in this
/// file: fixed-width, centered desktop `Dialog`s, never a mobile bottom
/// sheet. One shell, reused everywhere, so the console reads as one
/// coherent product instead of screens with different modal styles.

/// Fixed-width centered dialog shell used by every admin action.
class AdminDialog extends StatelessWidget {
  final double width;
  final Widget child;
  const AdminDialog({super.key, required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(padding: const EdgeInsets.all(22), child: child),
      ),
    );
  }
}

/// Desktop equivalent of `confirmSheet` — a small yes/no dialog instead
/// of a sheet sliding up from the bottom.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AdminDialog(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(confirmLabel, maxLines: 1)),
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

/// A single row inside a "manage this record" dialog (used by Members
/// and Coaches today, generic enough for anything else that needs a
/// small list of actions for one record).
class RecordActionItem {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const RecordActionItem({required this.icon, required this.color, required this.label, required this.onTap});
}

Future<void> showRecordActionsDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<RecordActionItem> actions,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AdminDialog(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(height: 12),
          ...actions.map((a) => Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: a.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        Icon(a.icon, color: a.color, size: 19),
                        const SizedBox(width: 12),
                        Text(a.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    ),
  );
}
