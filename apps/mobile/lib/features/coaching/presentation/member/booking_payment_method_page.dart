import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Provider availability is authoritative; this view never invents a bank.
class BookingPaymentMethodPage extends StatelessWidget {
  const BookingPaymentMethodPage(
      {super.key,
      required this.data,
      required this.selected,
      required this.loading,
      required this.message,
      required this.onSelect,
      required this.onContinue,
      required this.onRetry,
      this.reviewedQuote});
  final BookingPaymentMethods? data;
  final BookingPaymentQuote? reviewedQuote;
  final String? selected, message;
  final bool loading;
  final ValueChanged<String> onSelect;
  final VoidCallback? onContinue;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final quote = reviewedQuote ?? data?.quote;
    final methods = data?.methods ?? const <BookingPaymentMethod>[];
    return Scaffold(
        appBar: AppBar(title: const Text('Payment method')),
        body: PageBody(children: [
          Text('Choose a payment method',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: AppColors.ink)),
          const SizedBox(height: 8),
          const Text('One step closer to your next session.'),
          const SizedBox(height: 20),
          if (quote != null)
            Panel(
                background: AppColors.primaryTint,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.fitness_center_rounded,
                                color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(quote.coachName,
                                    style:
                                        Theme.of(context).textTheme.titleLarge))
                          ]),
                      const SizedBox(height: 12),
                      Text('${quote.durationMinutes}-minute coaching session'),
                      if (data?.localDate != null)
                        Text(
                            '${data!.localDate} · ${data!.startLabel} – ${data!.endLabel}'),
                      const SizedBox(height: 6),
                      Text(quote.branchName),
                      const Divider(height: 28),
                      Text('Total to pay',
                          style: Theme.of(context).textTheme.labelLarge),
                      Text(quote.formattedAmount,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                      if (quote.voucherApplied)
                        const Text('Premium Coach voucher included'),
                    ])),
          const SizedBox(height: 20),
          if (loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Finding available payment methods…')
          ],
          if (!loading && message != null) ...[
            Text(message!),
            TextButton(onPressed: onRetry, child: const Text('Try again'))
          ],
          if (!loading &&
              message == null &&
              data != null &&
              methods.isEmpty) ...[
            const Text(
                'No payment methods are available right now. Your reservation has not been charged.'),
            TextButton(onPressed: onRetry, child: const Text('Try again'))
          ],
          if (methods.any((m) => m.category == 'fpx')) ...[
            Text('FPX Online Banking',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
                'Choose your bank. Complete payment securely outside GainPath.'),
            const SizedBox(height: 12),
          ],
          for (final method in methods) _methodCard(context, method),
          const SizedBox(height: 12),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline_rounded,
                size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Payment is handled securely by Billplz. GainPath never asks for your banking password.'))
          ]),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: loading ? null : onContinue,
              child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Continue to Payment'))),
          const SizedBox(height: 8),
          const Text('Your booking is confirmed after payment is verified.',
              textAlign: TextAlign.center),
        ]));
  }

  Widget _methodCard(BuildContext context, BookingPaymentMethod method) {
    final active = selected == method.code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: active,
        button: true,
        child: Material(
          color: active ? AppColors.primaryTint : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                  color: active ? AppColors.primary : const Color(0xFFE3DDF0))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : () => onSelect(method.code),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(
                          method.category == 'fpx'
                              ? Icons.account_balance_rounded
                              : Icons.shield_outlined,
                          color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(method.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            method.category == 'fpx'
                                ? 'Online banking'
                                : 'Secure hosted payment',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 12))
                      ])),
                  const SizedBox(width: 8),
                  Icon(
                      active
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color:
                          active ? AppColors.primary : const Color(0xFF797183)),
                ])),
          ),
        ),
      ),
    );
  }
}
