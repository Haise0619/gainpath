import 'package:gainpath_domain/workout.dart'
    show ExerciseTrackingCapability, ExerciseTrackingRegistry;

/// Every kind has an exhaustive app-owned route; catalog content cannot add one.
enum ExerciseTracker {
  frontViewLateralRaise,
  frontViewShoulderPress,
  sideViewSquat,
  sideViewCurl,
  sideViewCalfRaise,
  sideViewWallPushUp,
  sideViewRow,
  sideViewReverseLunge
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
        ExerciseTracker.frontViewLateralRaise,
        ExerciseTracker.frontViewShoulderPress,
        ExerciseTracker.sideViewSquat,
        ExerciseTracker.sideViewCurl,
        ExerciseTracker.sideViewCalfRaise,
        ExerciseTracker.sideViewWallPushUp,
        ExerciseTracker.sideViewRow,
        ExerciseTracker.sideViewReverseLunge,
      }});
  final Set<ExerciseTracker> availableTrackers;
  static const _implementations = {
    ExerciseTracker.frontViewLateralRaise:
        ExerciseTrackingCapability.frontViewLateralRaise,
    ExerciseTracker.frontViewShoulderPress:
        ExerciseTrackingCapability.frontViewShoulderPress,
    ExerciseTracker.sideViewSquat: ExerciseTrackingCapability.sideViewSquat,
    ExerciseTracker.sideViewCurl: ExerciseTrackingCapability.sideViewCurl,
    ExerciseTracker.sideViewCalfRaise:
        ExerciseTrackingCapability.sideViewCalfRaise,
    ExerciseTracker.sideViewWallPushUp:
        ExerciseTrackingCapability.sideViewWallPushUp,
    ExerciseTracker.sideViewRow: ExerciseTrackingCapability.sideViewRow,
    ExerciseTracker.sideViewReverseLunge:
        ExerciseTrackingCapability.sideViewReverseLunge,
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
