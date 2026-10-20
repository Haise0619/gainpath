import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'availability_screens.dart';

/// Canonical Coach Availability view: renders the unified AvailabilityScreen.
class LiveCoachAvailabilityView extends StatelessWidget {
  const LiveCoachAvailabilityView({
    super.key,
    required this.repository,
    required this.coachId,
    required this.isCurrent,
  });

  final CoachAvailabilityRepository repository;
  final String coachId;
  final bool Function() isCurrent;

  @override
  Widget build(BuildContext context) => AvailabilityScreen(
        liveRepository: repository,
        coachId: coachId,
        isCurrent: isCurrent,
      );
}
