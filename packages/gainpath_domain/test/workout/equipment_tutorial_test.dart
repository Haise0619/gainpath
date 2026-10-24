import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  Map<String, dynamic> record() => {
        'schemaVersion': 1,
        'revision': 1,
        'isActive': true,
        'name': 'Lat pulldown',
        'category': 'Strength',
        'muscleGroup': 'Back',
        'description': 'Machine',
        'imageUrl': '',
        'howToUse': <String>[],
        'safetyTips': <String>[]
      };
  test('legacy equipment has no tutorial; tutorial survives copying', () {
    dynamic legacy = GymEquipment.fromDocument('e', record());
    expect(legacy.tutorialVideoUrl, '');
    dynamic entry = GymEquipment.fromDocument('e',
        {...record(), 'tutorialVideoUrl': 'https://example.com/tutorial.mp4'});
    expect(entry.copyWith(isActive: false).tutorialVideoUrl,
        'https://example.com/tutorial.mp4');
  });
  test('rejects non HTTPS tutorial references', () {
    expect(
        () => GymEquipment.fromDocument('e',
            {...record(), 'tutorialVideoUrl': 'http://example.com/video.mp4'}),
        throwsFormatException);
  });
}
