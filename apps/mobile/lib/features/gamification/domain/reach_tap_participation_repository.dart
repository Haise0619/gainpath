import 'package:gainpath_domain/gamification.dart';

/// Separate scoped earning reader for Reach & Tap, never the Move claim counter.
class ReachTapParticipationRepository {
  const ReachTapParticipationRepository(this.repository);
  final MiniGameParticipationRepository? repository;
}
