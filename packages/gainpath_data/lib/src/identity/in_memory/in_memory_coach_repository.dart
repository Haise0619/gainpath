import '../../fakes/mock_data_session.dart';
import 'identity_seed.dart';
import 'package:gainpath_domain/identity.dart';

/// Session-scoped in-memory [CoachRepository] backed by [IdentitySeed].
class InMemoryCoachRepository implements CoachRepository {
  InMemoryCoachRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).identity;

  final IdentitySeed _seed;

  @override
  String get coachName => _seed.coachName;

  @override
  String get coachEmail => _seed.coachEmail;

  @override
  String get coachPhone => _seed.coachPhone;

  @override
  Coach get currentCoach => _seed.currentCoach;

  @override
  List<CoachCertification> get coachCertifications => _seed.coachCertifications;

  @override
  List<Coach> get coaches => _seed.coaches;
}
