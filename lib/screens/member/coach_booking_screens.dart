import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M7.1 — Browse Professional Coaches.
class BrowseCoachesScreen extends StatefulWidget {
  const BrowseCoachesScreen({super.key});

  @override
  State<BrowseCoachesScreen> createState() => _BrowseCoachesScreenState();
}

class _BrowseCoachesScreenState extends State<BrowseCoachesScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final specialties = ['All', ...{for (final c in MockData.coaches) c.specialty}];
    final visible = _filter == 'All'
        ? MockData.coaches
        : MockData.coaches.where((c) => c.specialty == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coaches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note_rounded),
            tooltip: 'My bookings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BookingScheduleScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: specialties.map((s) {
                final selected = s == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = s),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text('No coaches match that filter.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: visible
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CoachCard(coach: c),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final Coach coach;
  const _CoachCard({required this.coach});

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CoachDetailScreen(coach: coach))),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                coach.name.split(' ').map((w) => w[0]).take(2).join(),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(coach.name,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (coach.verified) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded,
                          size: 15, color: AppColors.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(coach.specialty,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 15, color: AppColors.accent),
                    const SizedBox(width: 3),
                    Text('${coach.rating}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('  (${coach.reviews} reviews)',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ],
      ),
    );
  }
}

class CoachDetailScreen extends StatelessWidget {
  final Coach coach;
  const CoachDetailScreen({super.key, required this.coach});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(coach.name)),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      coach.name.split(' ').map((w) => w[0]).take(2).join(),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(coach.name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 3),
                Text(coach.specialty,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text('${coach.rating}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('  ·  ${coach.reviews} reviews',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('About'),
          Panel(
            child: Text(coach.bio,
                style: const TextStyle(fontSize: 14.5, height: 1.5)),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Session'),
          Panel(
            child: Column(
              children: const [
                DetailRow('Duration', '60 minutes'),
                Divider(height: 20),
                DetailRow('Fee', 'RM 120'),
                Divider(height: 20),
                DetailRow('Location', 'Fury Fitness, Kulim'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BookSessionScreen(coach: coach))),
            child: const Text('Book a session'),
          ),
        ],
      ),
    );
  }
}

/// AD-M7.2 — Book Coaching Session.
class BookSessionScreen extends StatefulWidget {
  final Coach coach;
  const BookSessionScreen({super.key, required this.coach});

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  int _day = 0;
  int? _slot;

  final _slots = const ['09:00', '10:30', '14:00', '15:30', '17:00', '18:30'];

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
        5, (i) => DateTime.now().add(Duration(days: i + 1)));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(title: const Text('Book a session')),
      body: PageBody(
        children: [
          const Eyebrow('Pick a day'),
          SizedBox(
            height: 78,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (ctx, i) {
                final selected = i == _day;
                final d = days[i];
                return GestureDetector(
                  onTap: () => setState(() {
                    _day = i;
                    _slot = null;
                  }),
                  child: Container(
                    width: 62,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.hairline),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayNames[d.weekday - 1],
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white70
                                    : AppColors.inkSoft)),
                        const SizedBox(height: 4),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color:
                                    selected ? Colors.white : AppColors.ink)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Available times'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_slots.length, (i) {
              final selected = _slot == i;
              final unavailable = i == 2;
              return GestureDetector(
                onTap: unavailable ? null : () => setState(() => _slot = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 13),
                  decoration: BoxDecoration(
                    color: unavailable
                        ? AppColors.surfaceAlt
                        : selected
                            ? AppColors.primary
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.hairline),
                  ),
                  child: Text(_slots[i],
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: unavailable
                            ? AppColors.inkSoft
                            : selected
                                ? Colors.white
                                : AppColors.ink,
                        decoration: unavailable
                            ? TextDecoration.lineThrough
                            : null,
                      )),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Panel(
            child: Column(
              children: [
                DetailRow('Coach', widget.coach.name),
                const Divider(height: 20),
                DetailRow('Date',
                    '${dayNames[days[_day].weekday - 1]} ${days[_day].day}'),
                const Divider(height: 20),
                DetailRow('Time', _slot == null ? 'Not selected' : _slots[_slot!]),
                const Divider(height: 20),
                const DetailRow('Total', 'RM 120.00'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _slot == null ? null : () => _pay(context),
            child: const Text('Continue to payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _pay(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      title: 'Pay RM 120.00',
      message:
          'You will be taken to the secure payment page to complete this booking. '
          'Your card details are handled by the payment provider, not by GainPath.',
      confirmLabel: 'Pay now',
    );
    if (!ok || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!context.mounted) return;
    Navigator.pop(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmedScreen(
          coach: widget.coach,
          time: _slots[_slot!],
        ),
      ),
    );
  }
}

class BookingConfirmedScreen extends StatelessWidget {
  final Coach coach;
  final String time;
  const BookingConfirmedScreen(
      {super.key, required this.coach, required this.time});

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.event_available_rounded,
                    size: 44, color: AppColors.primary),
                const SizedBox(height: 12),
                Text('You are booked in',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('${coach.name} at $time',
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              children: [
                DetailRow('Coach', coach.name),
                const Divider(height: 20),
                DetailRow('Time', time),
                const Divider(height: 20),
                const DetailRow('Location', 'Fury Fitness, Kulim'),
                const Divider(height: 20),
                const DetailRow('Paid', 'RM 120.00'),
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
}

/// AD-M7.3 — View Booking Schedule.
class BookingScheduleScreen extends StatelessWidget {
  const BookingScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final upcoming =
        MockData.memberBookings.where((b) => b.status == 'Confirmed').toList();
    final past =
        MockData.memberBookings.where((b) => b.status != 'Confirmed').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: PageBody(
        children: [
          const Eyebrow('Upcoming'),
          ...upcoming.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BookingCard(booking: b, upcoming: true),
              )),
          const SizedBox(height: 14),
          const Eyebrow('Past sessions'),
          ...past.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BookingCard(booking: b, upcoming: false),
              )),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final bool upcoming;
  const _BookingCard({required this.booking, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.coachName,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(_formatDate(booking.start),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              statusPill(booking.status),
            ],
          ),
          if (booking.notes != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 16, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(booking.notes!,
                          style: const TextStyle(
                              fontSize: 13.5, height: 1.4))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (upcoming)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42)),
                    onPressed: () =>
                        showToast(context, 'Pick a new slot to reschedule.'),
                    child: const Text('Reschedule'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () async {
                      final ok = await confirmSheet(context,
                          title: 'Cancel this session?',
                          message:
                              'Cancelling frees the slot for other members. You can cancel up to 12 hours before the start time.',
                          confirmLabel: 'Cancel session',
                          destructive: true);
                      if (ok) showToast(context, 'Session cancelled.');
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => _message(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () => _rate(context),
              icon: const Icon(Icons.star_outline_rounded, size: 19),
              label: const Text('Leave a review'),
            ),
        ],
      ),
    );
  }

  void _message(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20,
            20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Message ${booking.coachName}',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('About your session on ${_formatDate(booking.start)}',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                  hintText: 'Ask a question about this session'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                showToast(context, 'Message sent to ${booking.coachName}.');
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _rate(BuildContext context) {
    int stars = 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate your session',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text('with ${booking.coachName}',
                  style: Theme.of(ctx).textTheme.bodyMedium),
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
              const TextField(
                maxLines: 3,
                decoration:
                    InputDecoration(hintText: 'Anything you want to add?'),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: stars == 0
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        showToast(context, 'Thanks for your review.');
                      },
                child: const Text('Submit review'),
              ),
            ],
          ),
        ),
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
