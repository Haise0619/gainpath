import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import '../../features/workout/domain/admin_workout_program_repository.dart';

typedef ProgramAdminCall = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> input);

/// The callable owns publication and canonical authority. Client checks prevent
/// an old editing session from consuming or sending another account's data.
class FirebaseAdminWorkoutProgramRepository
    implements AdminWorkoutProgramRepository {
  FirebaseAdminWorkoutProgramRepository(
      {required this.scope,
      required bool Function() isCurrent,
      bool Function()? verifiedSession,
      Future<bool> Function()? ensureReady,
      ProgramAdminCall? call,
      Future<List<ProgramRoutineChoice>> Function()? loadRoutines})
      : _isCurrent = isCurrent,
        _verifiedSession = verifiedSession,
        _ensureReady = ensureReady ?? _firebaseReady,
        _call = call ?? _firebaseCall,
        _routines = loadRoutines;
  final SessionScope scope;
  final bool Function() _isCurrent;
  final bool Function()? _verifiedSession;
  final Future<bool> Function() _ensureReady;
  final ProgramAdminCall _call;
  final Future<List<ProgramRoutineChoice>> Function()? _routines;
  @override
  bool get current {
    if (!_isCurrent()) return false;
    if (_verifiedSession != null) return _verifiedSession();
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.uid == scope.userId && user?.emailVerified == true;
    } catch (_) {
      return false;
    }
  }

  void _guard() {
    if (!current) {
      throw StateError('Your editing session changed. Sign in again.');
    }
  }

  static Future<bool> _firebaseReady() async {
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) return true;
    // Activation remains owned by Admin bootstrap and its private build inputs.
    // Retry token acquisition per command after a transient attestation failure.
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _firebaseCall(
      Map<String, dynamic> input) async {
    final client = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      client.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1'),
          5001);
    }
    return Map<String, dynamic>.from((await client
            .httpsCallable('workoutProgramCommand')
            .call<Map<String, dynamic>>(input))
        .data);
  }

  Future<Map<String, dynamic>> _request(String action,
      [Map<String, dynamic> data = const {}]) async {
    _guard();
    final ready = await _ensureReady();
    _guard();
    if (!ready) {
      throw StateError(
          'App verification is unavailable. Retry to load Programs.');
    }
    final result = await _call({
      'schemaVersion': 1,
      'organizationId': scope.organizationId,
      'action': action,
      ...data
    });
    _guard();
    return result;
  }

  @override
  Future<AdminProgramCatalog> load() async {
    final response = await _request('adminList');
    final routines = await (_routines?.call() ?? _loadRoutines());
    _guard();
    final programs = (response['programs'] as List)
        .map(
            (e) => WorkoutProgram.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final drafts = (response['drafts'] as List).map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      return AdminProgramDraft(
          WorkoutProgram.fromJson(
              Map<String, dynamic>.from(row['program'] as Map)),
          row['revision'] as int);
    }).toList();
    return AdminProgramCatalog(
        programs: programs, drafts: drafts, routines: routines);
  }

  Future<List<ProgramRoutineChoice>> _loadRoutines() async {
    final result = await FirebaseFirestore.instance
        .collection('orgs')
        .doc(scope.organizationId)
        .collection('content')
        .where('status', isEqualTo: 'published')
        .where('kind', isEqualTo: 'routine')
        .limit(201)
        .get(const GetOptions(source: Source.server));
    _guard();
    if (result.docs.length > 200) {
      throw StateError('Published routine catalog is too large.');
    }
    return result.docs.map((d) {
      final data = d.data();
      if (data['title'] is! String || data['exercises'] is! List) {
        throw const FormatException('Invalid published routine');
      }
      return ProgramRoutineChoice(
          id: d.id, title: data['title'] as String, snapshot: data);
    }).toList();
  }

  @override
  Future<int> saveDraft(WorkoutProgram program,
      {required int expectedRevision, required String requestId}) async {
    final data = program.toJson();
    data['version'] = 0;
    data['days'] = (data['days'] as List)
        .map((e) =>
            Map<String, dynamic>.from(e as Map)..remove('routineSnapshot'))
        .toList();
    final result = await _request('saveDraft', {
      'program': data,
      'expectedRevision': expectedRevision,
      'requestId': requestId
    });
    if (result['revision'] is! int ||
        result['revision'] != expectedRevision + 1) {
      throw const FormatException('Draft save not confirmed');
    }
    return result['revision'] as int;
  }

  @override
  Future<AdminProgramDraft> publish(String programId,
      {required int expectedRevision, required String requestId}) async {
    final result = await _request('publish', {
      'programId': programId,
      'expectedRevision': expectedRevision,
      'requestId': requestId
    });
    final program = WorkoutProgram.fromJson(
        Map<String, dynamic>.from(result['program'] as Map));
    program.validate(published: true);
    if (program.id != programId ||
        program.version < 1 ||
        result['revision'] != expectedRevision + 1) {
      throw const FormatException('Publication not confirmed');
    }
    return AdminProgramDraft(program, result['revision'] as int);
  }
}
