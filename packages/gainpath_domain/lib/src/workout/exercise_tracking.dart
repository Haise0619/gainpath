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
  static const sideViewWallPushUp =
      ExerciseTrackingCapability._('wall_push_up_side_v1', 'side');
  static const sideViewRow =
      ExerciseTrackingCapability._('single_arm_row_side_v1', 'side');
  static const sideViewReverseLunge =
      ExerciseTrackingCapability._('bodyweight_reverse_lunge_side_v1', 'side');
  final String? trackerId, cameraView;
  bool get hasPoseTracking => trackerId != null;
  String get label => hasPoseTracking ? 'AI tracking' : 'Guided only';
  String get displayLabel => hasPoseTracking && cameraView == 'front'
      ? '$label · Front view'
      : hasPoseTracking && cameraView == 'side'
          ? '$label · Side view'
          : label;

  String get description => hasPoseTracking
      ? trackerId == frontViewLateralRaise.trackerId
          ? 'Front-view standing lateral raise · both arms together · provisional guidance'
          : trackerId == frontViewShoulderPress.trackerId
              ? 'Front-view dumbbell shoulder press · both arms together · provisional guidance'
              : trackerId == sideViewReverseLunge.trackerId
                  ? 'Side-view bodyweight reverse lunge · selected front leg only · provisional guidance'
                  : trackerId == sideViewRow.trackerId
                      ? 'Side-view selected-arm dumbbell row · provisional guidance'
                      : trackerId == sideViewCurl.trackerId
                          ? 'Side-view single-arm dumbbell curl · provisional form guidance'
                          : trackerId == sideViewCalfRaise.trackerId
                              ? 'Side-view standing calf raise · visible leg only · provisional form guidance'
                              : trackerId == sideViewWallPushUp.trackerId
                                  ? 'Side-view wall push-up · visible arm and body line · provisional guidance'
                                  : 'Side-view bodyweight squat · provisional form guidance'
      : 'Instructions and self-reported sets · no AI form score';
}

abstract final class ExerciseTrackingRegistry {
  // Match stable exercise variants, never a title or client-authored pose flag.
  static const _trackers = <String, ExerciseTrackingCapability>{
    'gainpath/standing-lateral-raise-front-v1':
        ExerciseTrackingCapability.frontViewLateralRaise,
    'gainpath/bodyweight-reverse-lunge-side-v1':
        ExerciseTrackingCapability.sideViewReverseLunge,
    'gainpath/dumbbell-shoulder-press-front-v1':
        ExerciseTrackingCapability.frontViewShoulderPress,
    'gainpath/F3b8xIr8ynBDd3gEICKX': ExerciseTrackingCapability.sideViewSquat,
    'gainpath/standing-single-arm-curl-side-v1':
        ExerciseTrackingCapability.sideViewCurl,
    'gainpath/standing-calf-raise-side-v1':
        ExerciseTrackingCapability.sideViewCalfRaise,
    'gainpath/wall-push-up-side-v1':
        ExerciseTrackingCapability.sideViewWallPushUp,
    'gainpath/single-arm-dumbbell-row-side-v1':
        ExerciseTrackingCapability.sideViewRow,
  };
  static ExerciseTrackingCapability resolve(
          {required String organizationId, required String exerciseId}) =>
      _trackers['$organizationId/$exerciseId'] ??
      ExerciseTrackingCapability.guidedOnly;
}
