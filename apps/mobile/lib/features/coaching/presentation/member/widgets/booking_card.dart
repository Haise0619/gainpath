import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

/// A single booking on "My bookings," with an action row that adapts to
/// the booking's own status rather than always showing the same three
/// buttons: Confirmed/Pending get reschedule/cancel/message, Completed
/// gets a review prompt (or a "you reviewed this" note once rated),
/// Cancelled surfaces the reason and a way to book that coach again.
class BookingCard extends StatelessWidget {
  final Booking booking;
  final bool live;
  final String? statusLabel;
  final Widget? details;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onMessage;
  final VoidCallback? onRate;
  final VoidCallback? onBookAgain;

  const BookingCard({
    super.key,
    required this.booking,
    this.live = false,
    this.statusLabel,
    this.details,
    this.onReschedule,
    this.onCancel,
    this.onMessage,
    this.onRate,
    this.onBookAgain,
  });

  Coach? _coach(BuildContext context) {
    for (final c in context.read<CoachRepository>().coaches) {
      if (c.id == booking.coachId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final coach = live ? null : _coach(context);
    final initial = booking.coachName.trim().isNotEmpty
        ? booking.coachName.trim()[0].toUpperCase()
        : 'C';
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
                  width: 48,
                  height: 48,
                  child: coach != null && coach.imageUrl.isNotEmpty
                      ? networkAvatar(coach.imageUrl)
                      : Container(
                          color: AppColors.primaryTint,
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.coachName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1-on-1 Consultation · ${booking.durationMin} min',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${_formatDate(booking.start)}  ·  ${booking.branch}',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: statusPill(statusLabel ?? booking.status.label)),
          if (booking.status == BookingStatus.cancelled &&
              booking.cancellationReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(booking.cancellationReason!,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ],
          if (booking.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(booking.notes!,
                        style: const TextStyle(fontSize: 13.5, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
          if (booking.rated) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text('You reviewed this session',
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (booking.reviewStars != null)
                    Text(' · ${booking.reviewStars}/5',
                        style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
          if (details != null)
            details!
          else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () => _showDetails(context),
                icon: const Icon(Icons.info_outline_rounded, size: 15),
                label: const Text('View details',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _actions(context),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Session Details',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _detailLine('Coach', booking.coachName),
            _detailLine('Session', '1-on-1 Consultation (${booking.durationMin} min)'),
            _detailLine('Date & Time', _formatDate(booking.start)),
            _detailLine('Location', booking.branch),
            _detailLine('Status', statusLabel ?? booking.status.label),
            _detailLine('Fee', 'RM ${booking.fee.toStringAsFixed(2)}'),
            if (booking.notes != null) _detailLine('Notes', booking.notes!),
            if (booking.cancellationReason != null)
              _detailLine('Cancellation', booking.cancellationReason!),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    switch (booking.status) {
      case BookingStatus.confirmed:
      case BookingStatus.pending:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                  minimumSize: const Size(0, 44),
                  foregroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onCancel,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Cancel', maxLines: 1),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
            ),
          ],
        );
      case BookingStatus.completed:
        if (booking.rated) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
            ),
          ],
        );
      case BookingStatus.cancelled:
        return Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onBookAgain,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Book again', maxLines: 1),
              ),
            ),
          ),
          if (onMessage != null) ...[
            const SizedBox(width: 8),
            IconButton.outlined(
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onMessage,
              tooltip: 'Booking message history',
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ]
        ]);
    }
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
