import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';
import 'support/floor_push_up_projection_fixture.dart';

// Characterization of the two visible peak angles, using analytic landmarks.
// These tests freeze existing behavior; they are not raw-video accuracy tests.
void main() {
  for (final right in [false, true]) {
    for (final peak in [152.61, 151.41]) {
      test(
          'release partial peak=$peak side=$right stays partial and reacquires TOP',
          () {
        final r = ProjectionReplay(right: right)..start();
        // Uncertain/revalidated geometry must not acquire a reliable form score.
        r.feed(85, forearm: .82);
        r.feed(85, forearm: .70);
        r.feed(85, forearm: .82);
        r.feed(85);
        for (final angle in [110.0, 130.0, 147.0, peak]) {
          r.hold(angle, 6);
        }
        expect(r.a.snapshot.repetitions, 0);
        for (final angle in [140.0, 120.0, 100.0]) {
          r.hold(angle, 6);
        }
        expect(r.a.snapshot.repetitions, 0);
        expect(r.a.snapshot.partialRepetitions, 1);
        expect(
            r.a.snapshot.issueCounts[FloorPushUpIssue.incompleteExtension], 1);
        expect(r.a.snapshot.formScorePercent, isNull);
        expect(r.a.diagnostics['resetReason'], 'incomplete_extension_reversal');
        expect(r.a.diagnostics['geometryAcceptance'], 'accepted');
        r.start();
        r.finishCycle();
        expect(r.a.snapshot.repetitions, 1);
        expect(r.a.snapshot.partialRepetitions, 1);
        r.hold(170, 15);
        expect(r.a.snapshot.repetitions, 1);
      });
    }
  }
}
