import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/admin_reporting_cubit.dart';

/// Request feedback stays inside the canonical report page.
class AdminReportingFeedback extends StatelessWidget {
  const AdminReportingFeedback(
      {super.key, required this.state, required this.onRetry});
  final AdminReportingState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: LinearProgressIndicator());
    }
    if (state.errorMessage == null) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Semantics(
            liveRegion: true,
            child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 18),
                          Text(state.errorMessage!,
                              style: const TextStyle(color: AppColors.danger)),
                          TextButton.icon(
                              onPressed: onRetry,
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.danger),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry reports'))
                        ])))));
  }
}
