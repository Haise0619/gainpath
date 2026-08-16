import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import 'coach_profile_screen.dart';
import 'message_coach_screen.dart';
import 'reschedule_screen.dart';
import 'widgets/booking_card.dart';

const _cancelReasons = [
  'Schedule conflict',
  'Feeling unwell',
  'Found a different time',
  'Other',
];

/// AD-M7.3 — View Booking Schedule. Three buckets — Upcoming, Completed,
/// Cancelled — each backed by the live `MockData.memberBookings` list, so
/// cancelling, rescheduling, or rating here (or from the coach's own
/// profile) is reflected immediately without any local copy to keep in
/// sync.
class BookingScheduleScreen extends StatefulWidget {
  const BookingScheduleScreen({super.key});

  @override
  State<BookingScheduleScreen> createState() => _BookingScheduleScreenState();
}

class _BookingScheduleScreenState extends State<BookingScheduleScreen> {
  Coach? _coachById(String id) {
    for (final c in MockData.coaches) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = MockData.memberBookings
        .where((b) => b.status == 'Confirmed' || b.status == 'Pending')
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final completed = MockData.memberBookings.where((b) => b.status == 'Completed').toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final cancelled = MockData.memberBookings.where((b) => b.status == 'Cancelled').toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: PageBody(
        children: [
          const Eyebrow('Upcoming'),
          if (upcoming.isEmpty)
            _emptyRow(context, 'Nothing booked yet.')
          else
            ...upcoming.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BookingCard(
                    booking: b,
                    onReschedule: () => _reschedule(b),
                    onCancel: () => _cancel(b),
                    onMessage: () => _message(b),
                  ),
                )),
          const SizedBox(height: 14),
          const Eyebrow('Completed'),
          if (completed.isEmpty)
            _emptyRow(context, 'No completed sessions yet.')
          else
            ...completed.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BookingCard(
                    booking: b,
                    onMessage: () => _message(b),
                    onRate: () => _rate(b),
                  ),
                )),
          const SizedBox(height: 14),
          const Eyebrow('Cancelled'),
          if (cancelled.isEmpty)
            _emptyRow(context, 'No cancelled sessions.')
          else
            ...cancelled.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BookingCard(
                    booking: b,
                    onBookAgain: () => _bookAgain(b),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _emptyRow(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  void _bookAgain(Booking b) {
    final coach = _coachById(b.coachId);
    if (coach == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CoachProfileScreen(coach: coach)));
  }

  Future<void> _reschedule(Booking b) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RescheduleScreen(booking: b)));
    if (mounted) setState(() {});
  }

  void _message(Booking b) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MessageCoachScreen(booking: b)));
  }

  Future<void> _cancel(Booking b) async {
    String? reason = _cancelReasons.first;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cancel this session?', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Cancelling frees the slot for other members. You can cancel up to 12 hours '
                'before the start time.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const Eyebrow('Reason'),
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (v) => setSheet(() => reason = v),
                child: Column(
                  children: _cancelReasons
                      .map((r) => RadioListTile<String>(
                            value: r,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(r, style: const TextStyle(fontSize: 14.5)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cancel session', maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Keep booking', maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      b.status = 'Cancelled';
      b.cancellationReason = 'Member requested — ${reason ?? _cancelReasons.first}.';
    });
    if (mounted) showToast(context, 'Session cancelled.');
  }

  Future<void> _rate(Booking b) async {
    int stars = 0;
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate your session', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('with ${b.coachName}', style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 18),
              Row(
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () => setSheet(() => stars = i + 1),
                    icon: Icon(
                      i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 34,
                      color: AppColors.accent,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Anything you want to add?'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: stars == 0 ? null : () => Navigator.pop(ctx),
                  child: const Text('Submit review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final reviewText = controller.text.trim();
    controller.dispose();
    if (stars == 0 || !mounted) return;
    setState(() {
      b.rated = true;
      final coach = _coachById(b.coachId);
      if (coach != null) {
        coach.topReviews.insert(
          0,
          CoachReview(
            MockData.memberName,
            stars,
            reviewText.isEmpty ? 'Great session.' : reviewText,
            DateTime.now(),
          ),
        );
      }
    });
    if (mounted) showToast(context, 'Thanks for your review.');
  }
}
