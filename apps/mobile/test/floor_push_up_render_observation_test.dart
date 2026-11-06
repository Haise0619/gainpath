import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_render_diagnostics.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/pose_landmark_painter.dart';
import 'support/floor_push_up_trajectory.dart';

void main() {
  testWidgets(
      'local render observation reports painter input without debug drawing',
      (tester) async {
    final diagnostics =
        PoseRenderDiagnostics(enabled: true, observationOnly: true);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    PoseLandmarkPainter(
            frame: floorFrame(1, 170),
            mirrored: false,
            diagnostics: diagnostics)
        .paint(canvas, const Size(200, 200));
    final pixels = await tester.runAsync(() async {
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 200);
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes;
    });
    expect(
        pixels!.getUint8(3), 0); // No diagnostic yellow border in the corner.
    final painted = diagnostics.snapshot['paint'] as Map;
    expect(painted['paintedFrameTimestampMicros'], 1);
    expect(painted['visibleAcceptedCount'], greaterThan(0));
    expect(diagnostics.snapshot['painterInvocationCount'], 1);
  });
}
