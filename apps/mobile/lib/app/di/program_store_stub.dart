import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/program_enrollment.dart';

Future<ProgramEnrollmentStore> createProgramEnrollmentStore(
        SessionScope scope) async =>
    throw UnsupportedError(
        'Program enrollment storage requires a supported device.');
