import 'member_booking_flow.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:flutter/material.dart';
import '../../application/booking_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/feature_navigation.dart';
import 'booking_confirmed_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' as persisted;

import 'widgets/booking_selection_page.dart';

/// AD-M7.2 — Book Coaching Session. Fee, day, and time all come from the
/// coach passed in; confirming payment creates a real `Booking` and adds
/// it to `allBookings`, so it shows up both on the member's "My
/// bookings" and on that coach's own roster — the two are filtered views
/// over one shared list, not separate data.
class BookSessionScreen extends StatefulWidget {
  final BookingSuggestionAttachment? suggestion;
  final Coach? coach;
  final BookingPaymentRepository? payments;
  final persisted.BookingCancellationRepository? cancellation;
  final persisted.MemberBookingOptionsRepository? options;
  final persisted.BookingRepository? writer;
  final String? coachId;
  final bool Function()? isCurrent;
  final VoidCallback? onOpenBookings;
  const BookSessionScreen(
      {super.key,
      this.coach,
      this.payments,
      this.cancellation,
      this.options,
      this.writer,
      this.coachId,
      this.isCurrent,
      this.onOpenBookings,
      this.suggestion});

  @override
  State<BookSessionScreen> createState() => _BookSessionScreenState();
}

class _BookSessionScreenState extends State<BookSessionScreen> {
  int _day = 0;
  int? _slot;

  final _slots = const ['09:00', '10:30', '14:00', '15:30', '17:00', '18:30'];

  @override
  Widget build(BuildContext context) {
    if (widget.options != null) {
      return MemberBookingFlow(
          options: widget.options!,
          writer: widget.writer!,
          payments: widget.payments,
          cancellation: widget.cancellation,
          coachId: widget.coachId!,
          isCurrent: widget.isCurrent!,
          onOpenBookings: widget.onOpenBookings!,
          suggestion: widget.suggestion);
    }
    final days =
        List.generate(5, (i) => DateTime.now().add(Duration(days: i + 1)));
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return BookingSelectionPage(
      days: [
        for (final entry in days.indexed)
          BookingDayOption(
              date: entry.$2,
              selected: entry.$1 == _day,
              onTap: () => setState(() {
                    _day = entry.$1;
                    _slot = null;
                  }))
      ],
      times: [
        for (final entry in _slots.indexed)
          BookingTimeOption(
              label: entry.$2,
              selected: entry.$1 == _slot,
              unavailable: entry.$1 == 2,
              onTap:
                  entry.$1 == 2 ? null : () => setState(() => _slot = entry.$1))
      ],
      details: [
        DetailRow('Coach', widget.coach!.name),
        DetailRow(
            'Date', '${dayNames[days[_day].weekday - 1]} ${days[_day].day}'),
        DetailRow('Time', _slot == null ? 'Not selected' : _slots[_slot!]),
        DetailRow('Location', widget.coach!.branch),
        DetailRow(
            'Total',
            widget.coach!.fee > 0
                ? 'RM ${widget.coach!.fee.toStringAsFixed(2)}'
                : '—')
      ],
      footer: [
        if (widget.coach!.fee <= 0)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'This coach does not have a valid consultation fee set. Booking checkout is unavailable.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          ),
        FilledButton(
            onPressed: (_slot == null || widget.coach!.fee <= 0) ? null : _pay,
            child: const Text('Continue to payment'))
      ],
    );
  }

  Future<void> _pay() async {
    final days =
        List.generate(5, (i) => DateTime.now().add(Duration(days: i + 1)));
    final selectedDay = days[_day];
    final timeParts = _slots[_slot!].split(':');
    final start = DateTime(selectedDay.year, selectedDay.month, selectedDay.day,
        int.parse(timeParts[0]), int.parse(timeParts[1]));

    final success = await Navigator.pushNamed<bool>(
      context,
      FeatureNavigation.checkout,
      arguments: CheckoutArguments(
        amount: widget.coach!.fee,
        description: 'Coaching session with ${widget.coach!.name}',
      ),
    );
    if (success != true || !mounted) return;

    final booking = Booking(
      id: 'b${DateTime.now().millisecondsSinceEpoch}',
      coachId: widget.coach!.id,
      coachName: widget.coach!.name,
      memberName: context.read<MemberProfileRepository>().memberName,
      start: start,
      branch: widget.coach!.branch,
      status: BookingStatus.confirmed,
      fee: widget.coach!.fee,
    );
    context.read<BookingBloc>().add(BookingCreated(booking));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => BookingConfirmedScreen(booking: booking)),
    );
  }
}
