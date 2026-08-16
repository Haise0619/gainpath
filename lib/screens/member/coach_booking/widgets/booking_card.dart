import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../data/mock_data.dart';
import '../../../../widgets/shared.dart';
import 'coach_card.dart';

/// A single booking on "My bookings," with an action row that adapts to
/// the booking's own status rather than always showing the same three
/// buttons: Confirmed/Pending get reschedule/cancel/message, Completed
/// gets a review prompt (or a "you reviewed this" note once rated),
/// Cancelled surfaces the reason and a way to book that coach again.
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onMessage;
  final VoidCallback? onRate;
  final VoidCallback? onBookAgain;

  const BookingCard({
    super.key,
    required this.booking,
    this.onReschedule,
    this.onCancel,
    this.onMessage,
    this.onRate,
    this.onBookAgain,
  });

  Coach? get _coach {
    for (final c in MockData.coaches) {
      if (c.id == booking.coachId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final coach = _coach;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: coach != null
                      ? networkAvatar(coach.imageUrl)
                      : Container(color: AppColors.surfaceAlt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.coachName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${_formatDate(booking.start)}  ·  ${booking.branch}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              statusPill(booking.status),
            ],
          ),
          if (booking.status == 'Cancelled' && booking.cancellationReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(booking.cancellationReason!,
                        style: const TextStyle(fontSize: 13.5, height: 1.4, color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ],
          if (booking.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(booking.notes!, style: const TextStyle(fontSize: 13.5, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
          if (booking.rated) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('You reviewed this session', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _actions(context),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    switch (booking.status) {
      case 'Confirmed':
      case 'Pending':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: onReschedule,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Reschedule', maxLines: 1),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42), foregroundColor: AppColors.danger),
                onPressed: onCancel,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Cancel', maxLines: 1),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
            ),
          ],
        );
      case 'Completed':
        if (booking.rated) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Message coach'),
            ),
          );
        }
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: onRate,
                icon: const Icon(Icons.star_outline_rounded, size: 19),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Leave a review', maxLines: 1),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
            ),
          ],
        );
      case 'Cancelled':
      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: onBookAgain,
            child: const Text('Book again'),
          ),
        );
    }
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
