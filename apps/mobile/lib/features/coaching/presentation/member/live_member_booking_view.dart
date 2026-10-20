import 'package:gainpath_domain/coaching.dart' show BookingPaymentRepository;
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'book_session_screen.dart';

/// Compatibility adapter for the original booking screen.
class LiveMemberBookingView extends StatelessWidget {
  const LiveMemberBookingView(
      {super.key,
      required this.options,
      required this.writer,
      this.payments,
      required this.coachId,
      required this.isCurrent,
      required this.onOpenBookings});
  final MemberBookingOptionsRepository options;
  final BookingRepository writer;
  final BookingPaymentRepository? payments;
  final String coachId;
  final bool Function() isCurrent;
  final VoidCallback onOpenBookings;
  @override
  Widget build(BuildContext context) => BookSessionScreen(
      options: options,
      writer: writer,
      payments: payments,
      coachId: coachId,
      isCurrent: isCurrent,
      onOpenBookings: onOpenBookings);
}
