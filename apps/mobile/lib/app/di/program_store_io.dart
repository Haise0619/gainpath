import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';
import '../../features/workout/domain/program_enrollment.dart';
import '../../infrastructure/local/file_program_enrollment_store.dart';

Future<ProgramEnrollmentStore> createProgramEnrollmentStore(
        SessionScope scope) async =>
    FileProgramEnrollmentStore(
        directory: await getApplicationSupportDirectory(), scope: scope);
