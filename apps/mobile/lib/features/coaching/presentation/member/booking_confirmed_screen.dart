import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/coaching.dart';

/// Confirmation uses the verified booking/payment response.
/// Payment responses retain the checkout schedule after rescheduling.
class BookingConfirmedScreen extends StatelessWidget {
  final Booking? booking;
  final BookingPaymentView? payment;
  final bool Function()? isCurrent;
  final VoidCallback? onViewBookings;
  const BookingConfirmedScreen(
      {super.key,
      this.booking,
      this.payment,
      this.isCurrent,
      this.onViewBookings})
      : assert(booking != null || payment != null);

  @override
  Widget build(BuildContext context) {
    if (isCurrent != null && !isCurrent!()) {
      return const Scaffold(
          body: Center(child: Text('Bookings unavailable for this account.')));
    }
    final payment = this.payment;
    if (payment != null &&
        (!payment.confirmed || payment.refundStatus != null)) {
      return const Scaffold(
          body: Center(child: Text('Booking is not confirmed.')));
    }
    final coachName = payment?.quote.coachName ?? booking!.coachName;
    final dateLabel = payment == null
        ? _formatDate(booking!.start)
        : '${payment.localDate} · ${payment.startLabel} – ${payment.endLabel}';
    final branch = payment?.quote.branchName ?? booking!.branch;
    final amount = payment?.quote.formattedAmount ??
        'RM ${booking!.fee.toStringAsFixed(2)}';
    return Scaffold(
      appBar: AppBar(
          title: const Text('Booking confirmed'),
          automaticallyImplyLeading: false),
      body: PageBody(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FAF5), shape: BoxShape.circle),
                child: Container(
                  width: 68, height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDDF4E7), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      size: 40, color: Color(0xFF16804A)),
                ),
              ),
              const SizedBox(height: 18),
              Text(payment != null ? 'Payment successful' : 'Booking confirmed',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Your coaching session is confirmed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                Row(children: [
                  const ExcludeSemantics(child: Icon(Icons.person_outline_rounded,
                      color: AppColors.primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(coachName,
                      style: Theme.of(context).textTheme.titleLarge)),
                ]),
                const Divider(height: 24, color: AppColors.hairline),
                DetailRow('Date & time', dateLabel),
                const Divider(height: 24, color: AppColors.hairline),
                DetailRow('Location', branch),
                const Divider(height: 24, color: AppColors.hairline),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: Text('Paid',
                        style: Theme.of(context).textTheme.bodyMedium)),
                    const SizedBox(width: 12),
                    Flexible(child: Text(amount, textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.ink, fontWeight: FontWeight.w700))),
                  ]),
                ),
                if (payment?.selectedPaymentMethod != null) ...[
                  const Divider(height: 24, color: AppColors.hairline),
                  PaymentMethodSummary(
                      label: payment!.selectedPaymentMethod!.choice.name,
                      category: 'Preferred payment method',
                      iconKey: payment.selectedPaymentMethod!.choice.iconKey)
                ],
                if (payment != null) ...[
                  const Divider(height: 24, color: AppColors.hairline),
                  DetailRow('Session length',
                      '${payment.quote.durationMinutes} minutes'),
                  const SizedBox(height: 12),
                  const Text(
                      'Booked time shown. Check My Bookings for any schedule changes.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              if (isCurrent != null && !isCurrent!()) return;
              if (onViewBookings != null) {
                Navigator.pop(context);
                onViewBookings!();
              } else {
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            child: Text(onViewBookings != null ? 'View My Bookings' : 'Done'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}  ·  $h:$m';
  }
}
