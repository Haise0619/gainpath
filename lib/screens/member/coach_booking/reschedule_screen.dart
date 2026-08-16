import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// Reschedule an existing confirmed/pending booking to a new day and
/// time. Mutates `booking.start` in place — the same `Booking` instance
/// already sitting in `MockData.memberBookings`, so nothing needs to be
/// re-fetched or replaced in the list for the change to show up back on
/// "My bookings."
class RescheduleScreen extends StatefulWidget {
  final Booking booking;
  const RescheduleScreen({super.key, required this.booking});

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  int _day = 0;
  int? _slot;

  final _slots = const ['09:00', '10:30', '14:00', '15:30', '17:00', '18:30'];

  @override
  Widget build(BuildContext context) {
    final days = List.generate(5, (i) => DateTime.now().add(Duration(days: i + 1)));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule session')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Currently booked for ${_formatDate(widget.booking.start)} with '
                    '${widget.booking.coachName}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Pick a new day'),
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
                      border: Border.all(color: selected ? AppColors.primary : AppColors.hairline),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayNames[d.weekday - 1],
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white70 : AppColors.inkSoft)),
                        const SizedBox(height: 4),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : AppColors.ink)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                  decoration: BoxDecoration(
                    color: unavailable
                        ? AppColors.surfaceAlt
                        : selected
                            ? AppColors.primary
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? AppColors.primary : AppColors.hairline),
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
                        decoration: unavailable ? TextDecoration.lineThrough : null,
                      )),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _slot == null ? null : () => _confirm(days),
            child: const Text('Confirm new time'),
          ),
        ],
      ),
    );
  }

  void _confirm(List<DateTime> days) {
    final selectedDay = days[_day];
    final timeParts = _slots[_slot!].split(':');
    final newStart = DateTime(selectedDay.year, selectedDay.month, selectedDay.day,
        int.parse(timeParts[0]), int.parse(timeParts[1]));
    widget.booking.start = newStart;
    Navigator.pop(context);
    showToast(context, 'Session moved to ${_formatDate(newStart)}.');
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
