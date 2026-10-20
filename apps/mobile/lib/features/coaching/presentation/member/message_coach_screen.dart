import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/identity.dart';
import '../coach/message_inbox_screen.dart';

/// Member adapter for the same booking conversation presentation used by Coach.
class MessageCoachScreen extends StatelessWidget {
  const MessageCoachScreen(
      {super.key, required this.booking, this.repository, this.isCurrent});
  final Booking booking;
  final BookingCommunicationRepository? repository;
  final bool Function()? isCurrent;
  @override
  Widget build(BuildContext context) {
    var responseTime = '-';
    if (repository == null) {
      for (final coach in context.read<CoachRepository>().coaches) {
        if (coach.id == booking.coachId) {
          responseTime = coach.responseTime;
          break;
        }
      }
    }
    return CoachMessageThreadScreen(
        booking: booking,
        repository: repository,
        isCurrent: isCurrent,
        ownRole: 'Member',
        responseTime: responseTime);
  }
}
