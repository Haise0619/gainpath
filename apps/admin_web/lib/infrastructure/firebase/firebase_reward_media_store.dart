import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/workout.dart';

class FirebaseRewardMediaStore {
  FirebaseRewardMediaStore(
      {required this.scope,
      required this.isCurrent,
      required Future<String> Function(String, Uint8List, String) upload})
      : _upload = upload;
  final SessionScope scope;
  final bool Function() isCurrent;
  final Future<String> Function(String, Uint8List, String) _upload;
  EquipmentImage? _pendingImage;
  String? _pendingId;

  Future<String> upload(EquipmentImage image) async {
    _check();
    if (!identical(_pendingImage, image)) {
      final random = Random.secure();
      _pendingId = List.generate(
              16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();
      _pendingImage = image;
    }
    final path =
        'orgs/${scope.organizationId}/rewardImages/${scope.userId}/$_pendingId';
    try {
      final url = await _upload(path, image.copyBytes(), image.contentType);
      _check();
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const RewardMediaUploadFailed();
      }
      _pendingImage = null;
      _pendingId = null;
      return url;
    } on RewardCatalogSessionChanged {
      rethrow;
    } on RewardMediaUploadFailed {
      rethrow;
    } on FirebaseException catch (error) {
      _check();
      throw RewardMediaUploadFailed(code: error.code);
    } on Error {
      _check();
      throw const RewardMediaUploadFailed(code: 'client-error');
    } catch (_) {
      _check();
      throw const RewardMediaUploadFailed();
    }
  }

  void _check() {
    if (!isCurrent()) throw const RewardCatalogSessionChanged();
  }
}
