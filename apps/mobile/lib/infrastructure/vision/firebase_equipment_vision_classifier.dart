import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_domain/workout.dart';
import '../firebase/firebase_function_transport.dart';

/// Vision classifier that invokes the Firebase Cloud Function callable.
/// This ensures API keys are stored securely on the server and NEVER embedded in the APK.
class FirebaseEquipmentVisionClassifier implements EquipmentVisionClassifier {
  FirebaseEquipmentVisionClassifier({
    required this.organizationId,
    FirebaseFunctions? functions,
    this.functionName = 'identifyEquipmentCommand',
  }) : _injectedFunctions = functions;

  final FirebaseFunctions? _injectedFunctions;
  final String functionName;
  final String organizationId;

  @override
  Future<EquipmentRecognitionResult> identifyEquipment(
    List<int> imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final base64String = base64Encode(imageBytes);

    final callable = firebaseCallable(
      functionName,
      functions: _injectedFunctions,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
    );

    final response = await callable.call<Map<String, dynamic>>({
      'organizationId': organizationId,
      'imageBase64': base64String,
      'mimeType': mimeType,
    });

    final data = Map<String, dynamic>.from(response.data);
    return EquipmentRecognitionResult.fromJson(data);
  }
}
