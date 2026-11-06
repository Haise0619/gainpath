/// Latest local state only. No logger, trace buffer, persistence or telemetry.
enum FloorPushUpRejection {
  none,
  noPose,
  invalidImage,
  mirroredInput,
  lowPoseConfidence,
  missingLandmark,
  outsideImage,
  lowLandmarkConfidence,
  bodyTooSmall,
  degenerateBody,
  armGeometry,
  hipProjection,
  farShoulderUnavailable,
  bodyNotHorizontal,
  notSideView,
  wristPosition,
  kneeSupport,
  unreliableWorld,
  contradictoryWorld,
  staleFrame,
  frameGap,
  cameraGeometryChanged,
  modelChanged,
  anchorDrift,
  limbChange,
  invalidTimestamp,
  trackingLost,
  waitingTop,
  stabilizingTop,
}

String floorPushUpReadinessMessage(FloorPushUpRejection reason) =>
    switch (reason) {
      FloorPushUpRejection.none => 'Ready — start your push-ups.',
      FloorPushUpRejection.noPose => 'No pose detected. Hold steady in view.',
      FloorPushUpRejection.missingLandmark ||
      FloorPushUpRejection.outsideImage =>
        'Move back to keep your full body visible.',
      FloorPushUpRejection.lowLandmarkConfidence ||
      FloorPushUpRejection.farShoulderUnavailable =>
        'Keep your near arm and both shoulders visible.',
      FloorPushUpRejection.bodyTooSmall =>
        'Move closer while keeping your whole body visible.',
      FloorPushUpRejection.notSideView => 'Turn sideways to the camera.',
      FloorPushUpRejection.bodyNotHorizontal ||
      FloorPushUpRejection.kneeSupport ||
      FloorPushUpRejection.wristPosition ||
      FloorPushUpRejection.waitingTop =>
        'Hold a high plank with arms extended to begin.',
      FloorPushUpRejection.stabilizingTop => 'Hold your high plank steady.',
      FloorPushUpRejection.contradictoryWorld =>
        'Turn fully sideways and hold steady.',
      FloorPushUpRejection.unreliableWorld =>
        'Tracking in 2D · form score unavailable.',
      FloorPushUpRejection.anchorDrift ||
      FloorPushUpRejection.cameraGeometryChanged =>
        'Keep your hands, feet and camera steady.',
      FloorPushUpRejection.mirroredInput ||
      FloorPushUpRejection.invalidImage =>
        'Camera orientation unavailable. Reopen the camera.',
      _ => 'Tracking lost. Hold steady.',
    };
