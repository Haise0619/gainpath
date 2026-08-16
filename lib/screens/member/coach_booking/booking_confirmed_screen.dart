import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// Shown right after a successful Billplz payment for a coaching
/// session. Takes the actual [Booking] that was just created (and
/// already added to `MockData.memberBookings`) rather than loose
/// coach/time parameters, so every figure shown here is guaranteed to
/// match what "My bookings" will show afterwards.
class BookingConfirmedScreen extends StatelessWidget {
  final Booking booking;
  const BookingConfirmedScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking confirmed'), automaticallyImplyLeading: false),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.primaryTint,
            child: Column(
              children: [
                const Icon(Icons.event_available_rounded, size: 44, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('You are booked in', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('${booking.coachName} at ${_formatDate(booking.start)}',
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                DetailRow('Coach', booking.coachName),
                const Divider(height: 20),
                DetailRow('Date & time', _formatDate(booking.start)),
                const Divider(height: 20),
                DetailRow('Location', booking.branch),
                const Divider(height: 20),
                DetailRow('Paid', 'RM ${booking.fee.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}  ·  $h:$m';
  }
}
