import 'package:gainpath_domain/coaching.dart' show BookingPaymentRepository;
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'book_session_screen.dart';
import 'package:gainpath_domain/chatbot.dart';

/// Compatibility adapter for the original booking screen.
class LiveMemberBookingView extends StatelessWidget {
  const LiveMemberBookingView(
      {super.key,
      required this.options,
      required this.writer,
      this.payments,
      this.cancellation,
      this.suggestion,
      required this.coachId,
      required this.isCurrent,
      required this.onOpenBookings});
  final MemberBookingOptionsRepository options;
  final BookingRepository writer;
  final BookingPaymentRepository? payments;
  final BookingCancellationRepository? cancellation;
  final BookingSuggestionAttachment? suggestion;
  final String coachId;
  final bool Function() isCurrent;
  final VoidCallback onOpenBookings;
  @override
  Widget build(BuildContext context) => BookSessionScreen(
      options: options,
      writer: writer,
      payments: payments,
      cancellation: cancellation,
      suggestion: suggestion,
      coachId: coachId,
      isCurrent: isCurrent,
      onOpenBookings: onOpenBookings);
}
