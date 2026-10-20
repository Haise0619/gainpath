import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:test/test.dart';

CueRequest cue(String id, CuePriority priority) =>
    CueRequest(id: id, text: id, priority: priority);

void main() {
  test('cooling warning does not starve an eligible correction', () {
    final arbiter = AudioCueArbiter();
    arbiter.submit(cue('lost', CuePriority.warning));
    expect(arbiter.takeNext(nowMicros: 0)?.id, 'lost');
    arbiter.submit(cue('lost', CuePriority.warning));
    arbiter.submit(cue('depth', CuePriority.correction));
    expect(arbiter.takeNext(nowMicros: 1)?.id, 'depth');
    expect(arbiter.takeNext(nowMicros: 2000000)?.id, 'lost');
  });

  test('repeated submissions coalesce instead of replaying duplicates', () {
    final arbiter = AudioCueArbiter();
    for (var i = 0; i < 100; i++) {
      arbiter.submit(cue('depth', CuePriority.correction));
    }
    expect(arbiter.takeNext(nowMicros: 0)?.id, 'depth');
    expect(arbiter.takeNext(nowMicros: 2000000), isNull);
  });

  test('clearing queued frame cues retains dispatched cooldown', () {
    final arbiter = AudioCueArbiter();
    arbiter.submit(cue('depth', CuePriority.correction));
    arbiter.takeNext(nowMicros: 0);
    arbiter.submit(cue('old', CuePriority.warning));
    arbiter.clearPending();
    expect(arbiter.takeNext(nowMicros: 1), isNull);
    arbiter.submit(cue('depth', CuePriority.correction));
    expect(arbiter.takeNext(nowMicros: 1), isNull);
  });
}
