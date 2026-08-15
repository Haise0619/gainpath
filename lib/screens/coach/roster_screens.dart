import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M9.1 — View Upcoming Session Schedule.
class CoachRosterScreen extends StatefulWidget {
  const CoachRosterScreen({super.key});

  @override
  State<CoachRosterScreen> createState() => _CoachRosterScreenState();
}

class _CoachRosterScreenState extends State<CoachRosterScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final visible = _filter == 'All'
        ? MockData.coachRoster
        : MockData.coachRoster.where((b) => b.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My roster')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                    child: StatTile('${MockData.coachRoster.length}', 'Sessions')),
                const SizedBox(width: 10),
                const Expanded(child: StatTile('3', 'This week')),
                const SizedBox(width: 10),
                const Expanded(
                    child: StatTile('4.8', 'Rating',
                        valueColor: AppColors.accent)),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', 'Confirmed', 'Pending', 'Completed'].map((s) {
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: visible
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SessionCard(booking: b),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Booking booking;
  const _SessionCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final isPast = booking.start.isBefore(DateTime.now());
    return Panel(
      child: Column(
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
                child: Center(
                  child: Text(
                    booking.memberName
                        .split(' ')
                        .map((w) => w[0])
                        .take(2)
                        .join(),
                    style: const TextStyle(
                        fontSize: 15,
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
                    Text(booking.memberName,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(_fmt(booking.start),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              statusPill(booking.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ClientPostureScreen(name: booking.memberName))),
                  child: const Text('Form history'),
                ),
              ),
              const SizedBox(width: 8),
              if (isPast)
                Expanded(
                  child: FilledButton(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ConsultationNotesScreen(booking: booking))),
                    child: const Text('Write notes'),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42)),
                    onPressed: () => showToast(context, 'Reply sent.'),
                    child: const Text('Message'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => confirmSheet(context,
                      title: 'Cancel this session?',
                      message:
                          'The member is notified and the slot reopens for booking. Any refund is handled separately by staff.',
                      confirmLabel: 'Cancel session',
                      destructive: true),
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}  ·  $h:$m';
  }
}

/// AD-M9.2 — Generate Post-Workout Consultation Notes.
class ConsultationNotesScreen extends StatefulWidget {
  final Booking booking;
  const ConsultationNotesScreen({super.key, required this.booking});

  @override
  State<ConsultationNotesScreen> createState() =>
      _ConsultationNotesScreenState();
}

class _ConsultationNotesScreenState extends State<ConsultationNotesScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation notes')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: [
                DetailRow('Client', widget.booking.memberName),
                const Divider(height: 20),
                const DetailRow('Session', 'Lower Body Strength'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Your notes'),
          TextField(
            controller: _controller,
            maxLines: 8,
            decoration: InputDecoration(
              hintText:
                  'How did the session go? Note any technique changes or things to watch next time.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Publishing these notes marks the session as complete and lets '
                    'the member leave a review.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              if (_controller.text.trim().isEmpty) {
                setState(() => _error = 'Add some notes before publishing.');
                return;
              }
              Navigator.pop(context);
              showToast(context, 'Notes published. Session marked complete.');
            },
            child: const Text('Publish notes'),
          ),
        ],
      ),
    );
  }
}

/// UC-9.5 — View Client Posture History.
class ClientPostureScreen extends StatelessWidget {
  final String name;
  const ClientPostureScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: PageBody(
        children: [
          const Eyebrow('Form accuracy trend'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrendChart(MockData.postureTrend),
                const SizedBox(height: 10),
                Text('Improving steadily over the last 7 sessions.',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('By movement'),
          Panel(
            child: Column(
              children: const [
                ProgressRow('Dumbbell Row', 0.88, '88%',
                    color: AppColors.success),
                ProgressRow('Barbell Squat', 0.84, '84%',
                    color: AppColors.success),
                ProgressRow('Overhead Press', 0.79, '79%',
                    color: AppColors.warning),
                ProgressRow('Romanian Deadlift', 0.71, '71%',
                    color: AppColors.danger),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            background: AppColors.dangerTint,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 20, color: AppColors.danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Watch the hinge pattern',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(
                        'Lumbar rounding appears on the last two sets of most RDL '
                        'sessions. Worth reviewing setup cues next session.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
