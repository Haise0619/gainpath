import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import '../real_squat_session_test.dart' show Camera, Detector;
import '../workout_voice_readiness_test.dart' show RetryAudio;

final _scope = SessionScope(userId: 'visual-test', organizationId: 'gainpath');

/// Real session lifecycle with controlled display snapshots; no pose claims.
class VisualFeedbackSession extends RealSquatSessionController {
  VisualFeedbackSession()
      : super(
          scope: _scope,
          activeScope: () => _scope,
          camera: Camera(),
          detectorFactory: () async => Detector(),
          audioPort: RetryAudio(),
          repository: WorkoutSessionRepository(
              scope: _scope,
              activeScope: () => _scope,
              store: InMemoryWorkoutSessionStore(scope: _scope),
              uploadGateway: UnavailableWorkoutUploadGateway()),
          clockMicros: () => 100000,
          sessionId: 'visual-feedback',
          exerciseId: 'squat',
          publishedRoutineId: 'visual-routine',
          detectorId: 'fixture',
          detectorVersion: '1',
          provenance: WorkoutProvenance.recordedFixture,
          guidance: GuidedWorkoutProgress(sets: 3, repetitions: 8),
        );

  WorkoutAnalysisView? snapshot;
  bool snapshotAvailable = true, automaticRest = false;
  @override
  WorkoutAnalysisView? get analysis => snapshot;
  @override
  bool get analysisAvailable => snapshot != null && snapshotAvailable;
  @override
  bool get isPaused => automaticRest || super.isPaused;

  void update(
      {int reps = 0,
      bool calibrating = false,
      TrackingStatus health = TrackingStatus.healthy,
      bool available = true,
      bool rest = false,
      int? guidedReps}) {
    snapshotAvailable = available;
    automaticRest = rest;
    snapshot = WorkoutAnalysisView(
        repetitions: reps,
        partialRepetitions: 0,
        trackedDurationMicros: 0,
        rejectedDurationMicros: 0,
        formScorePercent: null,
        needsCalibration: calibrating,
        health: health,
        cues: const []);
    guidance!.observe(guidedReps ?? reps, nowMicros: 100000);
    notifyListeners();
  }
}
