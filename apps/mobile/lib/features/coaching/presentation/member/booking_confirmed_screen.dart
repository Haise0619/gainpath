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
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              children: [
                Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        size: 44, color: AppColors.primary)),
                const SizedBox(height: 12),
                if (payment != null)
                  Text('Payment successful',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.primary)),
                const SizedBox(height: 6),
                Text('You are booked in',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('$coachName at $dateLabel',
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                DetailRow('Coach', coachName),
                const Divider(height: 20),
                DetailRow('Date & time', dateLabel),
                const Divider(height: 20),
                DetailRow('Location', branch),
                const Divider(height: 20),
                DetailRow('Paid', amount),
                if (payment != null) ...[
                  const Divider(height: 20),
                  DetailRow('Session length',
                      '${payment.quote.durationMinutes} minutes'),
                  const SizedBox(height: 12),
                  const Text(
                      'This is the time booked at checkout. My Bookings shows your current time if you rescheduled.'),
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
