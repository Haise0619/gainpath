/// Available local exercise logic, independent of catalog authoring and of
/// server acceptance/reward policies. A pose model alone is not an analyzer.
class ExerciseTrackingCapability {
  const ExerciseTrackingCapability._(this.trackerId, this.cameraView);
  static const guidedOnly = ExerciseTrackingCapability._(null, null);
  static const frontViewLateralRaise =
      ExerciseTrackingCapability._('standing_lateral_raise_front_v1', 'front');
  static const frontViewShoulderPress =
      ExerciseTrackingCapability._('dumbbell_shoulder_press_front_v1', 'front');
  static const sideViewSquat =
      ExerciseTrackingCapability._('bodyweight_squat_side_v1', 'side');
  static const sideViewCurl =
      ExerciseTrackingCapability._('single_arm_curl_side_v1', 'side');
  static const sideViewCalfRaise =
      ExerciseTrackingCapability._('standing_calf_raise_side_v1', 'side');
  static const sideViewFloorPushUp =
      ExerciseTrackingCapability._('standard_floor_push_up_side_v1', 'side');
  final String? trackerId, cameraView;
  bool get hasPoseTracking => trackerId != null;
  String get label => hasPoseTracking ? 'AI tracking' : 'Guided only';
  String get displayLabel => hasPoseTracking && cameraView == 'front'
      ? '$label · Front view'
      : hasPoseTracking && cameraView == 'side'
          ? '$label · Side view'
          : label;

  String get description => switch (this) {
        sideViewFloorPushUp =>
          'Standard Floor Push-Up · Left Side View or Right Side View · provisional visible-side form guidance',
        frontViewLateralRaise =>
          'Front-view standing lateral raise · both arms together · provisional guidance',
        frontViewShoulderPress =>
          'Front-view dumbbell shoulder press · both arms together · provisional guidance',
        sideViewCurl =>
          'Side-view single-arm dumbbell curl · provisional form guidance',
        sideViewCalfRaise =>
          'Side-view standing calf raise · visible leg only · provisional form guidance',
        sideViewSquat =>
          'Side-view bodyweight squat · provisional form guidance',
        _ => 'Instructions and self-reported sets · no AI form score',
      };
}

abstract final class ExerciseTrackingRegistry {
  // Match stable exercise variants, never a title or client-authored pose flag.
  static const _trackers = <String, ExerciseTrackingCapability>{
    'gainpath/standing-lateral-raise-front-v1':
        ExerciseTrackingCapability.frontViewLateralRaise,
    'gainpath/dumbbell-shoulder-press-front-v1':
        ExerciseTrackingCapability.frontViewShoulderPress,
    'gainpath/F3b8xIr8ynBDd3gEICKX': ExerciseTrackingCapability.sideViewSquat,
    'gainpath/standing-single-arm-curl-side-v1':
        ExerciseTrackingCapability.sideViewCurl,
    'gainpath/standing-calf-raise-side-v1':
        ExerciseTrackingCapability.sideViewCalfRaise,
    'gainpath/standard-floor-push-up-side-v1':
        ExerciseTrackingCapability.sideViewFloorPushUp,
  };

  /// Previously tracked catalog rows remain usable as manual exercises.
  static bool isRetired({
    required String organizationId,
    required String exerciseId,
  }) =>
      organizationId == 'gainpath' &&
      const {
        'wall-push-up-side-v1',
        'single-arm-dumbbell-row-side-v1',
        'bodyweight-reverse-lunge-side-v1',
      }.contains(exerciseId);

  static ExerciseTrackingCapability resolve(
          {required String organizationId, required String exerciseId}) =>
      _trackers['$organizationId/$exerciseId'] ??
      ExerciseTrackingCapability.guidedOnly;
}
