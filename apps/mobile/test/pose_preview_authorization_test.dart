import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/pose_preview_route.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:google_fonts/google_fonts.dart';
import 'workout_preferences_test.dart' show MemoryWorkoutPreferencesStore;

class PreviewAuthRepository extends InMemoryAuthRepository {
  AuthSession? current = const AuthSession(
      userId: 'preview-member',
      organizationId: 'gainpath',
      email: 'fixture@example.invalid',
      role: AppRole.member);
  final changes = StreamController<AuthSession?>.broadcast(sync: true);
  @override
  Stream<AuthSession?> get sessionChanges => changes.stream;
  @override
  Future<AuthSession?> restoreSession() async => current;
  void change(AuthSession? value) {
    current = value;
    changes.add(value);
  }

  @override
  Future<void> dispose() async {
    await changes.close();
    await super.dispose();
  }
}

class PreviewCamera implements PoseCameraSource {
  int starts = 0, invalidations = 0, stops = 0;
  bool denied = false;
  Completer<void>? opening;
  void Function(PoseInput)? receive;
  @override
  Future<void> start(void Function(PoseInput) callback) async {
    if (denied) throw PoseCameraPermissionDenied();
    starts++;
    receive = callback;
    await opening?.future;
  }

  @override
  void invalidate() {
    invalidations++;
  }

  @override
  Future<void> stop() async {
    stops++;
    receive = null;
  }
}

class PreviewDetector implements ManagedPoseDetector {
  int closes = 0, detects = 0;
  @override
  Future<PoseFrame> detect(PoseInput input) async {
    detects++;
    return PoseFrame(
        capturedAtMicros: input.timestampMicros,
        detectorId: 'fixture',
        modelVersion: '1',
        landmarks: {});
  }

  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {
    closes++;
  }
}

class PreviewAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

AuthState previewAuthState(AuthSession? session) => session == null
    ? const AuthState()
    : AuthState(
        status: AuthStatus.signedIn, session: session, role: session.role);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late PreviewAuthRepository repository;
  late AuthBloc auth;
  late WorkoutPreferencesController preferences;
  late PreviewCamera camera;
  late PreviewDetector detector;
  late List<PosePreviewController> sessions;
  Completer<ManagedPoseDetector>? model;
  Completer<WorkoutPreferencesController>? loading;

  setUp(() {
    repository = PreviewAuthRepository();
    auth = PreviewAuthBloc();
    whenListen(auth, repository.changes.stream.map(previewAuthState),
        initialState: previewAuthState(repository.current));
    camera = PreviewCamera();
    detector = PreviewDetector();
    sessions = [];
    model = null;
    loading = null;
  });
  tearDown(() async {
    preferences.dispose();
    await auth.close();
    await repository.dispose();
  });

  Future<void> initialize() async {
    preferences = WorkoutPreferencesController(
        scope: auth.state.session!.scope,
        store: MemoryWorkoutPreferencesStore());
    await preferences.load();
    await preferences.grantConsent();
  }

  Future<void> open(WidgetTester tester, {Key? key}) async {
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: PosePreviewRoute(
                key: key,
                preferencesFactory: (_) =>
                    loading?.future ?? Future.value(preferences),
                controllerFactory: (scope, activeScope, clock) {
                  final controller = PosePreviewController(
                      scope: scope,
                      activeScope: activeScope,
                      camera: camera,
                      detectorFactory: () =>
                          model?.future ?? Future.value(detector),
                      clockMicros: clock);
                  sessions.add(controller);
                  return controller;
                },
                viewportBuilder: (_) => const SizedBox.shrink()))));
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'preview needs persisted consent and authorized re-entry can open',
      (tester) async {
    await initialize();
    await preferences.withdrawConsent();
    await open(tester);
    expect(camera.starts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await preferences.grantConsent();
    await open(tester, key: UniqueKey());
    expect(camera.starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final reason in ['withdrawal', 'logout', 'account', 'role', 'account-return', 'role-return']) {
    testWidgets('preview invalidates immediately on $reason and cannot restart',
        (tester) async {
      await initialize();
      await open(tester);
      expect(camera.starts, 1);
      final callback = camera.receive!;
      if (reason == 'withdrawal') {
        await preferences.withdrawConsent();
      } else {
        final original = repository.current!;
        repository.change(reason == 'logout'
            ? null
            : AuthSession(
                userId:
                    reason.startsWith('account') ? 'another-member' : 'preview-member',
                organizationId: 'gainpath',
                email: 'fixture@example.invalid',
                role: reason.startsWith('role') ? AppRole.coach : AppRole.member));
        await tester.pump();
        if (reason.endsWith('return')) {
          repository.change(original);
          await tester.pump();
        }
      }
      expect(sessions.single.phase, PosePreviewPhase.closed);
      callback(PoseInput(timestampMicros: 1));
      await sessions.single.resume();
      await tester.pump();
      expect(detector.detects, 0);
      expect(camera.starts, 1);
      if (reason == 'withdrawal') await preferences.grantConsent();
      await tester.pump();
      expect(camera.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
      'withdrawal during model initialization closes the late model without camera',
      (tester) async {
    await initialize();
    model = Completer<ManagedPoseDetector>();
    await open(tester);
    await preferences.withdrawConsent();
    model!.complete(detector);
    await tester.pump();
    await tester.pump();
    expect(camera.starts, 0);
    expect(detector.closes, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('withdrawal during camera opening cannot deliver or resume',
      (tester) async {
    await initialize();
    camera.opening = Completer<void>();
    await open(tester);
    final callback = camera.receive!;
    await preferences.withdrawConsent();
    camera.opening!.complete();
    callback(PoseInput(timestampMicros: 1));
    await tester.pump();
    await tester.pump();
    expect(sessions.single.phase, PosePreviewPhase.closed);
    expect(detector.detects, 0);
    expect(camera.stops, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
      'background during preferences load invalidates startup across foreground return',
      (tester) async {
    await initialize();
    loading = Completer<WorkoutPreferencesController>();
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    loading!.complete(preferences);
    await tester.pump();
    await tester.pump();
    expect(camera.starts, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
      'OS camera denial remains fail closed and permits deliberate retry',
      (tester) async {
    await initialize();
    camera.denied = true;
    await open(tester);
    expect(sessions.single.phase, PosePreviewPhase.failure);
    expect(sessions.single.errorMessage, contains('permission'));
    camera.denied = false;
    await sessions.single.resume();
    await tester.pump();
    expect(camera.starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
