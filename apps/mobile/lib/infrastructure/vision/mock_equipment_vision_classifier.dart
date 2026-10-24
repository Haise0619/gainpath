import 'package:gainpath_domain/workout.dart';

/// Predictable mock classifier for testing and offline/mock mode demonstration.
class MockEquipmentVisionClassifier implements EquipmentVisionClassifier {
  MockEquipmentVisionClassifier({
    this.forcedResult,
    this.simulateDelay = true,
  });

  EquipmentRecognitionResult? forcedResult;
  final bool simulateDelay;
  int _counter = 0;

  static const List<EquipmentRecognitionResult> defaultSequence = [
    EquipmentRecognitionResult(
      detectedEquipment: 'Squat Rack',
      aliases: ['Power Rack', 'Power Cage'],
      category: 'Compound Lower-Body',
      confidence: 0.96,
      isGymEquipment: true,
    ),
    EquipmentRecognitionResult(
      detectedEquipment: 'Adjustable Bench',
      aliases: ['Incline Bench', 'Weight Bench'],
      category: 'Isolation Upper-Body',
      confidence: 0.92,
      isGymEquipment: true,
    ),
    EquipmentRecognitionResult(
      detectedEquipment: 'Dumbbell Rack',
      aliases: ['Dumbbells', 'Free Weights'],
      category: 'Isolation Upper-Body',
      confidence: 0.89,
      isGymEquipment: true,
    ),
    EquipmentRecognitionResult(
      detectedEquipment: 'Cable Crossover Machine',
      aliases: ['Dual Cable Cross', 'Cable Machine'],
      category: 'Cable & Machine',
      confidence: 0.95,
      isGymEquipment: true,
    ),
    EquipmentRecognitionResult(
      detectedEquipment: 'Treadmill',
      aliases: ['Running Machine'],
      category: 'Cardio',
      confidence: 0.97,
      isGymEquipment: true,
    ),
    EquipmentRecognitionResult(
      detectedEquipment: 'Water Bottle',
      aliases: ['Drink Bottle'],
      confidence: 0.80,
      isGymEquipment: false,
    ),
  ];

  @override
  Future<EquipmentRecognitionResult> identifyEquipment(
    List<int> imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (simulateDelay) {
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    if (forcedResult != null) return forcedResult!;
    final index = _counter++ % defaultSequence.length;
    return defaultSequence[index];
  }
}
