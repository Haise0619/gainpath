import 'package:gainpath/features/identity/data/in_memory/identity_seed.dart';
import 'package:gainpath/features/identity/domain/entities/coach.dart';
import 'package:gainpath/features/identity/domain/entities/coach_certification.dart';
import 'package:gainpath/features/identity/domain/repositories/coach_repository.dart';

/// Session-scoped in-memory [CoachRepository] backed by [IdentitySeed].
class InMemoryCoachRepository implements CoachRepository {
  @override
  String get coachName => IdentitySeed.coachName;

  @override
  String get coachEmail => IdentitySeed.coachEmail;

  @override
  String get coachPhone => IdentitySeed.coachPhone;

  @override
  Coach get currentCoach => IdentitySeed.currentCoach;

  @override
  List<CoachCertification> get coachCertifications => IdentitySeed.coachCertifications;

  @override
  List<Coach> get coaches => IdentitySeed.coaches;
}
