import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/workout/domain/enums/tutorial_status.dart';

void main() {
  test('labels round-trip', () {
    for (final s in TutorialStatus.values) {
      expect(TutorialStatus.fromLabel(s.label), s);
    }
  });
}
