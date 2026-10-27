import 'package:test/test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test(
      'legacy exercises have optional defaults; rich details preserve step order',
      () {
    expect(ExerciseTutorialDetails.fromJson({}).steps, isEmpty);
    final details = ExerciseTutorialDetails.fromJson({
      'description': ' Overview ',
      'coverImageUrl': 'https://media.example.test/cover.jpg',
      'difficulty': 'Intermediate',
      'equipment': ' Mat ',
      'tutorialSteps': [
        {
          'title': ' Set up ',
          'description': ' Stand tall. ',
          'imageUrl':
              'https://media.example.test/o/image?alt=media&token=fixture'
        },
        {'title': 'Move', 'description': 'Lower slowly.'},
      ],
    });
    expect(details.description, 'Overview');
    expect(details.equipment, 'Mat');
    expect(details.steps.map((s) => s.title), ['Set up', 'Move']);
    expect(ExerciseTutorialDetails.fromJson(details.toJson()).toJson(),
        details.toJson());
  });
  test(
      'bounded instructions reject empty steps, excessive steps and unsafe images',
      () {
    for (final data in <Map<String, dynamic>>[
      {
        'tutorialSteps': [
          {'title': '', 'description': 'Step'}
        ]
      },
      {
        'tutorialSteps':
            List.filled(13, {'title': 'Step', 'description': 'Move'})
      },
      {'coverImageUrl': 'file:///private.jpg'},
      {'coverImageUrl': 'https://user:password@media.example.test/image.jpg'},
      {'difficulty': 'Unknown'},
    ]) {
      expect(
          () => ExerciseTutorialDetails.fromJson(data), throwsFormatException);
    }
    expect(
        ExerciseTutorialDetails.fromJson(
                {'coverImageUrl': 'http://invalid/image.jpg'},
                tolerateInvalidImages: true)
            .coverImageUrl,
        isEmpty);
  });
}
