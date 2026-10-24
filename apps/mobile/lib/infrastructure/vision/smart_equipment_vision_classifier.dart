import 'package:gainpath_domain/workout.dart';
import 'firebase_equipment_vision_classifier.dart';
import 'mock_equipment_vision_classifier.dart';

/// Live recognition uses only the authenticated server callable.
class SmartEquipmentVisionClassifier implements EquipmentVisionClassifier {
  SmartEquipmentVisionClassifier(
      {required bool connected, String? organizationId})
      : _delegate = connected
            ? FirebaseEquipmentVisionClassifier(
                organizationId: organizationId ??
                    (throw ArgumentError(
                        'Organization is required for live scanning.')))
            : MockEquipmentVisionClassifier();

  final EquipmentVisionClassifier _delegate;

  @override
  Future<EquipmentRecognitionResult> identifyEquipment(List<int> imageBytes,
          {String mimeType = 'image/jpeg'}) =>
      _delegate.identifyEquipment(imageBytes, mimeType: mimeType);
}
