import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/pose_worker_termination.dart';

void main() {
  testWidgets('requesting worker stop is not proof that native work exited',
      (tester) async {
    final lifetime = PoseWorkerTermination();
    var stopped = false, confirmed = false;
    lifetime.stopAndConfirm(() => stopped = true).then((_) => confirmed = true);
    await tester.pump(const Duration(seconds: 20));
    expect(stopped, isTrue);
    expect(confirmed, isFalse);
    lifetime.exited();
    await tester.pump();
    expect(confirmed, isTrue);
    lifetime.exited();
  });
}
