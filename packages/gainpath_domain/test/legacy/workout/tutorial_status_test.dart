import 'package:test/test.dart';
import 'package:gainpath_domain/src/workout/enums/tutorial_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in TutorialStatus.values) {
      expect(TutorialStatus.fromLabel(s.label), s);
    }
  });
}
