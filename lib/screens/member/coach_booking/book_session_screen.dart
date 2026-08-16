import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../../../widgets/billplz_checkout_screen.dart';
import 'booking_confirmed_screen.dart';

/// AD-M7.2 — Book Coaching Session. Fee, day, and time all come from the
/// coach passed in; confirming payment creates a real `Booking` and adds
/// it to `MockData.allBookings`, so it shows up both on the member's "My
/// bookings" and on that coach's own roster — the two are filtered views
/// over one shared list, not separate data.
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
    final days = List.generate(5, (i) => DateTime.now().add(Duration(days: i + 1)));
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
          Panel(
            child: Column(
              children: [
                DetailRow('Coach', widget.coach.name),
                const Divider(height: 20),
                DetailRow('Date', '${dayNames[days[_day].weekday - 1]} ${days[_day].day}'),
                const Divider(height: 20),
                DetailRow('Time', _slot == null ? 'Not selected' : _slots[_slot!]),
                const Divider(height: 20),
                DetailRow('Location', widget.coach.branch),
                const Divider(height: 20),
                DetailRow('Total', 'RM ${widget.coach.fee.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _slot == null ? null : _pay,
            child: const Text('Continue to payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _pay() async {
    final days = List.generate(5, (i) => DateTime.now().add(Duration(days: i + 1)));
    final selectedDay = days[_day];
    final timeParts = _slots[_slot!].split(':');
    final start = DateTime(selectedDay.year, selectedDay.month, selectedDay.day,
        int.parse(timeParts[0]), int.parse(timeParts[1]));

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BillplzCheckoutScreen(
          amount: widget.coach.fee,
          description: 'Coaching session with ${widget.coach.name}',
        ),
      ),
    );
    if (success != true || !mounted) return;

    final booking = Booking(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      coachId: widget.coach.id,
      coachName: widget.coach.name,
      memberName: MockData.memberName,
      start: start,
      branch: widget.coach.branch,
      status: 'Confirmed',
      fee: widget.coach.fee,
    );
    MockData.allBookings.add(booking);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BookingConfirmedScreen(booking: booking)),
    );
  }
}
