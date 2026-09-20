import '../entities/coach.dart';
import '../entities/coach_certification.dart';

/// Data access contract for the identity feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class CoachRepository {
  String get coachName;
  String get coachEmail;
  String get coachPhone;
  Coach get currentCoach;
  List<CoachCertification> get coachCertifications;
  List<Coach> get coaches;
}
