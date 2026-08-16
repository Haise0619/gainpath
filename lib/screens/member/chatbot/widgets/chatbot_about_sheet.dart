import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';

/// The AI coach's About/disclaimer popup, shared between the forced
/// first-open path (`dismissible: false` — the member must tap "Got
/// it"; back button and tap-outside are both blocked) and the
/// on-demand Help (?) button, which reopens the same content as a
/// normal, dismissible dialog.
///
/// Rendered as a centered overlay rather than a bottom sheet: the
/// disclaimer text plus the FAQ list is taller than a bottom sheet's
/// default height budget on most phones, and `showModalBottomSheet`
/// doesn't scroll on its own, so it was overflowing. A dialog gets an
/// explicit max height with the FAQ list scrolling inside it instead —
/// the header and "Got it" button stay pinned in view either way.
Future<void> showChatbotAboutSheet(BuildContext context, {bool dismissible = true}) {
  return showDialog(
    context: context,
    barrierDismissible: dismissible,
    builder: (ctx) => PopScope(
      canPop: dismissible,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.info_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('About this assistant', style: Theme.of(ctx).textTheme.titleLarge),
                    ),
                    if (dismissible)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: AppColors.inkSoft,
                        onPressed: () => Navigator.pop(ctx),
                        tooltip: 'Close',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'The AI coach gives general fitness and technique guidance only. '
                          'It cannot diagnose injuries, prescribe treatment, or replace advice '
                          'from a doctor or physiotherapist.\n\n'
                          'If something hurts, stop and speak to a qualified professional.',
                          style: Theme.of(ctx).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 18),
                        Text('Try asking about', style: Theme.of(ctx).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...MockData.faqPrompts.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 7),
                                  child: Icon(Icons.circle, size: 5, color: AppColors.inkSoft),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(p.question, style: Theme.of(ctx).textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
