import 'package:gainpath_domain/workout.dart'
    show ExerciseTrackingCapability, ExerciseTrackingRegistry;

/// Every kind has an exhaustive app-owned route; catalog content cannot add one.
enum ExerciseTracker {
  sideViewSquat,
  sideViewCurl,
  sideViewCalfRaise,
  sideViewWallPushUp
}

class ExerciseTrackerResolution {
  const ExerciseTrackerResolution._(this.registeredCapability, this.tracker);
  final ExerciseTrackingCapability registeredCapability;
  final ExerciseTracker? tracker;
  ExerciseTrackingCapability get capability => tracker == null
      ? ExerciseTrackingCapability.guidedOnly
      : registeredCapability;
  bool get unavailable =>
      registeredCapability.hasPoseTracking && tracker == null;
  String get description => unavailable
      ? 'AI tracking is unavailable for this exercise. Follow the tutorial and mark sets as done yourself.'
      : capability.description;
}

/// Intersects exact catalog identity with implementations installed in this app.
/// This does not change server acceptance or recover from camera/model failures.
class ExerciseTrackerDispatcher {
  const ExerciseTrackerDispatcher(
      {this.availableTrackers = const {
        ExerciseTracker.sideViewSquat,
        ExerciseTracker.sideViewCurl,
        // Calf tracking is held after the owner's unsuccessful phone trials.
        ExerciseTracker.sideViewWallPushUp,
      }});
  final Set<ExerciseTracker> availableTrackers;
  static const _implementations = {
    ExerciseTracker.sideViewSquat: ExerciseTrackingCapability.sideViewSquat,
    ExerciseTracker.sideViewCurl: ExerciseTrackingCapability.sideViewCurl,
    ExerciseTracker.sideViewCalfRaise:
        ExerciseTrackingCapability.sideViewCalfRaise,
    ExerciseTracker.sideViewWallPushUp:
        ExerciseTrackingCapability.sideViewWallPushUp,
  };

  ExerciseTrackerResolution resolve(
      {required String organizationId, required String exerciseId}) {
    final registered = ExerciseTrackingRegistry.resolve(
        organizationId: organizationId, exerciseId: exerciseId);
    for (final implementation in _implementations.entries) {
      if (registered.hasPoseTracking &&
          registered.trackerId == implementation.value.trackerId &&
          availableTrackers.contains(implementation.key)) {
        return ExerciseTrackerResolution._(registered, implementation.key);
      }
    }
    return ExerciseTrackerResolution._(registered, null);
  }
}
