import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

typedef AdminAiInvoke = Future<Object?> Function(
    String operation, Map<String, Object?> data);
typedef AdminAiCoachPhotoInvoke = Future<Object?> Function(
    String organizationId, String coachId);

Map<String, dynamic> aiMap(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : throw const FormatException('Invalid AI response.');
String aiRequestId() => List.generate(16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

class AdminAiRepository {
  AdminAiRepository(
      {required this.organizationId,
      required bool Function() isCurrent,
      required AdminAiInvoke invoke,
      AdminAiCoachPhotoInvoke? invokeCoachPhoto})
      : _current = isCurrent,
        _invoke = invoke,
        _invokeCoachPhoto = invokeCoachPhoto;
  final String organizationId;
  final bool Function() _current;
  final AdminAiInvoke _invoke;
  final AdminAiCoachPhotoInvoke? _invokeCoachPhoto;
  bool get current => _current();
  Future<Map<String, dynamic>> call(
      String operation, Map<String, Object?> input) async {
    if (!current) throw StateError('Your Admin session changed.');
    final result = aiMap(await _invoke(operation,
        {'schemaVersion': 1, 'organizationId': organizationId, ...input}));
    if (!current) throw StateError('Your Admin session changed.');
    return result;
  }

  Future<Uint8List?> loadCoachPhoto(String coachId, String photoPath) async {
    final invoke = _invokeCoachPhoto;
    if (invoke == null || coachId.isEmpty) return null;
    try {
      if (!current) return null;
      final result = await invoke(organizationId, coachId);
      if (!current) return null;
      final data = aiMap(result);
      final encoded = data['bytesBase64'];
      if (data['schemaVersion'] != 1 ||
          data['photoPath'] != photoPath ||
          encoded is! String ||
          encoded.length > 7 * 1024 * 1024 ||
          !['image/jpeg', 'image/png', 'image/webp']
              .contains(data['contentType'])) {
        return null;
      }
      final bytes = base64Decode(encoded);
      return bytes.length <= 5 * 1024 * 1024 ? bytes : null;
    } catch (_) {
      return null;
    }
  }
}
