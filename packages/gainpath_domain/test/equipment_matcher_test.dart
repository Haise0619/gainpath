import 'package:gainpath_domain/workout.dart';
import 'package:test/test.dart';

void main() {
  final catalog = [
    GymEquipment(
      id: 'eq1',
      name: 'Squat Rack',
      category: 'Compound Lower-Body',
      description: 'Fixed barbell rack with adjustable safety arms.',
      howToUse: ['Set J-hooks to shoulder height.'],
      safetyTips: ['Set safety arms before lifting.'],
      imageUrl: 'https://example.com/squat_rack.jpg',
      muscleGroup: 'Quads · Glutes',
      isActive: true,
    ),
    GymEquipment(
      id: 'eq2',
      name: 'Standing Press Station',
      category: 'Compound Upper-Body',
      description: 'Open barbell station for standing overhead press.',
      howToUse: ['Clean bar to shoulder height.'],
      safetyTips: ['Brace core.'],
      imageUrl: 'https://example.com/press.jpg',
      muscleGroup: 'Shoulders · Triceps',
      isActive: true,
    ),
    GymEquipment(
      id: 'eq3',
      name: 'Adjustable Bench',
      category: 'Isolation Upper-Body',
      description: 'Flat-to-incline bench for dumbbell work.',
      howToUse: ['Set incline.'],
      safetyTips: ['Check pin is locked.'],
      imageUrl: 'https://example.com/bench.jpg',
      muscleGroup: 'Chest · Shoulders',
      isActive: true,
    ),
    GymEquipment(
      id: 'eq4',
      name: 'Dumbbell Rack',
      category: 'Isolation Upper-Body',
      description: 'Tiered rack holding pairs of dumbbells.',
      howToUse: ['Pick matching weights.'],
      safetyTips: ['Lift with neutral spine.'],
      imageUrl: 'https://example.com/dumbbells.jpg',
      muscleGroup: 'Full Body',
      isActive: true,
    ),
    GymEquipment(
      id: 'eq5',
      name: 'Cable Crossover Machine',
      category: 'Cable & Machine',
      description: 'Dual-tower cable station with pulleys.',
      howToUse: ['Select pin weight.'],
      safetyTips: ['Check carabiner clip.'],
      imageUrl: 'https://example.com/cable.jpg',
      muscleGroup: 'Chest · Back',
      isActive: true,
    ),
    GymEquipment(
      id: 'eq6',
      name: 'Treadmill',
      category: 'Cardio',
      description: 'Motorised running belt.',
      howToUse: ['Straddle belt before starting.'],
      safetyTips: ['Attach safety key.'],
      imageUrl: 'https://example.com/treadmill.jpg',
      muscleGroup: 'Cardiovascular',
      isActive: true,
    ),
    GymEquipment(
      id: 'eq-inactive',
      name: 'Broken Leg Press',
      category: 'Compound Lower-Body',
      description: 'Out of order machine.',
      howToUse: ['Do not use.'],
      safetyTips: ['Out of order.'],
      imageUrl: 'https://example.com/leg_press.jpg',
      muscleGroup: 'Legs',
      isActive: false,
    ),
  ];

  const matcher = EquipmentMatcher();
  test('identical active names retain every tied candidate for confirmation',
      () {
    final result = matcher.match(
      recognition: const EquipmentRecognitionResult(
          detectedEquipment: 'Squat Rack', confidence: 0.99),
      catalog: [
        catalog.first,
        GymEquipment(
            id: 'rack-2',
            name: 'Squat Rack',
            category: 'Compound Lower-Body',
            description: '',
            howToUse: [],
            safetyTips: [],
            imageUrl: '',
            muscleGroup: '',
            isActive: true)
      ],
    );
    expect(result, isA<MultipleEquipmentMatches>());
    expect((result as MultipleEquipmentMatches).candidates, hasLength(2));
  });

  for (final confidence in [
    0.0,
    0.79,
    -1.0,
    1.01,
    double.nan,
    double.infinity
  ]) {
    test('rejects exact name with invalid or uncertain confidence $confidence',
        () {
      expect(
          matcher.match(
              recognition: EquipmentRecognitionResult(
                  detectedEquipment: 'Squat Rack', confidence: confidence),
              catalog: catalog),
          isA<NoEquipmentMatch>());
    });
  }

  test('rejects missing gym-equipment evidence in JSON', () {
    final prediction = EquipmentRecognitionResult.fromJson({
      'detectedEquipment': 'Squat Rack',
      'confidence': 0.99,
    });
    expect(matcher.match(recognition: prediction, catalog: catalog),
        isA<NoEquipmentMatch>());
  });

  group('EquipmentMatcher tests', () {
    test('exact match succeeds for Squat Rack', () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Squat Rack',
        confidence: 0.98,
        isGymEquipment: true,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<SingleEquipmentMatch>());
      final match = result as SingleEquipmentMatch;
      expect(match.equipment.id, 'eq1');
      expect(match.equipment.name, 'Squat Rack');
      expect(match.score, greaterThanOrEqualTo(0.95));
    });

    test('alias match succeeds for Power Rack -> Squat Rack', () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Power Rack',
        aliases: ['Power Cage', 'Squat Stand'],
        confidence: 0.92,
        isGymEquipment: true,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<SingleEquipmentMatch>());
      final match = result as SingleEquipmentMatch;
      expect(match.equipment.id, 'eq1');
      expect(match.equipment.name, 'Squat Rack');
    });

    test('alias match succeeds for Incline Bench -> Adjustable Bench', () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Incline Bench',
        aliases: ['Weight Bench', 'Flat Bench'],
        confidence: 0.90,
        isGymEquipment: true,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<SingleEquipmentMatch>());
      final match = result as SingleEquipmentMatch;
      expect(match.equipment.id, 'eq3');
      expect(match.equipment.name, 'Adjustable Bench');
    });

    test('alias match succeeds for Cable Machine -> Cable Crossover Machine',
        () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Cable Machine',
        aliases: ['Dual Cable Cross', 'Pulley Machine'],
        confidence: 0.94,
        isGymEquipment: true,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<SingleEquipmentMatch>());
      final match = result as SingleEquipmentMatch;
      expect(match.equipment.id, 'eq5');
    });

    test('inactive equipment is never matched', () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Broken Leg Press',
        aliases: ['Leg Press'],
        confidence: 0.99,
        isGymEquipment: true,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<NoEquipmentMatch>());
    });

    test('non-gym item returns NoEquipmentMatch', () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Coffee Mug',
        aliases: ['Cup', 'Beverage'],
        confidence: 0.85,
        isGymEquipment: false,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<NoEquipmentMatch>());
    });

    test('unknown equipment returns NoEquipmentMatch', () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Space Shuttle Cockpit',
        aliases: ['Aircraft'],
        confidence: 0.50,
        isGymEquipment: true,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<NoEquipmentMatch>());
    });

    test('case and punctuation normalization work seamlessly', () {
      const recognition = EquipmentRecognitionResult(
        detectedEquipment: '   tReAdMiLl!!   ',
        confidence: 0.95,
        isGymEquipment: true,
      );

      final result = matcher.match(recognition: recognition, catalog: catalog);
      expect(result, isA<SingleEquipmentMatch>());
      expect((result as SingleEquipmentMatch).equipment.id, 'eq6');
    });

    test('ambiguous match returns MultipleEquipmentMatches', () {
      final benchPressCatalog = [
        GymEquipment(
          id: 'eq-flat-bench',
          name: 'Flat Bench',
          category: 'Isolation Upper-Body',
          description: 'Standard flat bench.',
          howToUse: ['Lie down.'],
          safetyTips: ['Keep feet flat.'],
          imageUrl: 'https://example.com/flat.jpg',
          muscleGroup: 'Chest',
          isActive: true,
        ),
        GymEquipment(
          id: 'eq-incline-bench',
          name: 'Incline Bench',
          category: 'Isolation Upper-Body',
          description: 'Standard incline bench.',
          howToUse: ['Lie down.'],
          safetyTips: ['Keep feet flat.'],
          imageUrl: 'https://example.com/incline.jpg',
          muscleGroup: 'Chest',
          isActive: true,
        ),
      ];

      const recognition = EquipmentRecognitionResult(
        detectedEquipment: 'Bench',
        aliases: ['Gym Bench'],
        confidence: 0.80,
        isGymEquipment: true,
      );

      final result = matcher.match(
        recognition: recognition,
        catalog: benchPressCatalog,
      );
      expect(result, isA<MultipleEquipmentMatches>());
      final multiple = result as MultipleEquipmentMatches;
      expect(multiple.candidates.length, 2);
    });

    test('serialization of EquipmentRecognitionResult', () {
      const result = EquipmentRecognitionResult(
        detectedEquipment: 'Squat Rack',
        aliases: ['Power Cage'],
        category: 'Compound Lower-Body',
        confidence: 0.97,
        isGymEquipment: true,
        rawResponse: '{"detectedEquipment": "Squat Rack"}',
      );

      final json = result.toJson();
      final parsed = EquipmentRecognitionResult.fromJson(json);

      expect(parsed.detectedEquipment, 'Squat Rack');
      expect(parsed.aliases, ['Power Cage']);
      expect(parsed.category, 'Compound Lower-Body');
      expect(parsed.confidence, 0.97);
      expect(parsed.isGymEquipment, true);
      expect(parsed.rawResponse, '{"detectedEquipment": "Squat Rack"}');
    });
  });
}
