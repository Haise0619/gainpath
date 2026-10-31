import 'dart:typed_data';
import '../identity.dart' show SessionScope;

/// Descriptive overrides for a game implemented by the application.
/// Camera, timing, scoring, consent and rewards are never editable fields.
class MiniGameContent {
  MiniGameContent(
      {required this.organizationId,
      this.gameId = supportedId,
      this.revision = 0,
      required this.title,
      required this.introduction,
      required Iterable<String> instructions,
      this.coverUrl = '',
      this.previewVideoUrl = '',
      this.updatedAtMillis = 0})
      : instructions = List.unmodifiable(instructions);
  static const supportedId = 'move-catch-v1';
  static const reachTapId = 'reach-tap-v1';
  static const supportedIds = {supportedId, reachTapId};
  static const maxCoverBytes = 5 * 1024 * 1024;
  static const maxPreviewBytes = 20 * 1024 * 1024;
  final String organizationId,
      gameId,
      title,
      introduction,
      coverUrl,
      previewVideoUrl;
  final int revision, updatedAtMillis;
  final List<String> instructions;
  bool get isBuiltIn => revision == 0;
  factory MiniGameContent.defaults(String organizationId,
      {String gameId = supportedId}) {
    if (!supportedIds.contains(gameId)) {
      throw ArgumentError.value(gameId, 'gameId', 'Unsupported mini-game.');
    }
    if (gameId == reachTapId) {
      return MiniGameContent(
          organizationId: organizationId,
          gameId: gameId,
          title: 'Reach & Tap',
          introduction:
              'Reach with your hands to touch fixed targets in a 40-second round.',
          instructions: const [
            'Face the camera with your body and both hands visible for alignment.',
            'Hold steady until Ready, then the countdown starts automatically.',
            'Move within your calibrated space and touch targets with an observed hand. Each confirmed hit earns 10 Game Score.',
          ]);
    }
    return MiniGameContent(
        organizationId: organizationId,
        title: 'Move & Catch',
        introduction:
            'Lean left and right to catch stars and avoid obstacles in a 40-second round.',
        instructions: const [
          'Face the camera with your shoulders and hips visible.',
          'Hold your starting position for calibration, then start the round.',
          'Lean gently to catch stars and avoid diamonds. Return into view during the tracking warning.',
        ]);
  }
  MiniGameContent copyWith(
          {String? title,
          String? introduction,
          Iterable<String>? instructions,
          String? coverUrl,
          String? previewVideoUrl}) =>
      MiniGameContent(
          organizationId: organizationId,
          gameId: gameId,
          revision: revision,
          updatedAtMillis: updatedAtMillis,
          title: title ?? this.title,
          introduction: introduction ?? this.introduction,
          instructions: instructions ?? this.instructions,
          coverUrl: coverUrl ?? this.coverUrl,
          previewVideoUrl: previewVideoUrl ?? this.previewVideoUrl);

  static bool validMediaUrl(String url, String organizationId, String kind,
      {String gameId = supportedId}) {
    if (!supportedIds.contains(gameId) || !['cover', 'preview'].contains(kind)) {
      return false;
    }
    if (url.isEmpty) return true;
    if (url.length > 2048 || RegExp(r'[\s\\]').hasMatch(url)) return false;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'firebasestorage.googleapis.com' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    final p = uri.pathSegments, q = uri.queryParametersAll;
    if (p.length != 5 ||
        p[0] != 'v0' ||
        p[1] != 'b' ||
        p[2] != 'gainpath-0619.firebasestorage.app' ||
        p[3] != 'o' ||
        q.length != 2 ||
        q.values.any((v) => v.length != 1) ||
        uri.queryParameters['alt'] != 'media' ||
        !RegExp(r'^[a-fA-F0-9-]{36}$')
            .hasMatch(uri.queryParameters['token'] ?? '')) {
      return false;
    }
    final object = p[4].split('/');
    return object.length == 7 &&
        object[0] == 'orgs' &&
        object[1] == organizationId &&
        object[2] == 'miniGameMedia' &&
        object[3] == gameId &&
        object[4] == kind &&
        RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(object[5]) &&
        RegExp(r'^[a-f0-9]{32}$').hasMatch(object[6]);
  }

  Map<String, dynamic> toFields() {
    bool text(String v, int max) =>
        v.trim().isNotEmpty &&
        v.length <= max &&
        !RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(v);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(organizationId) ||
        !supportedIds.contains(gameId) ||
        !text(title, 80) ||
        !text(introduction, 2000) ||
        instructions.isEmpty ||
        instructions.length > 8 ||
        instructions.any((v) => !text(v, 500)) ||
        !validMediaUrl(coverUrl, organizationId, 'cover', gameId: gameId) ||
        !validMediaUrl(previewVideoUrl, organizationId, 'preview',
            gameId: gameId)) {
      throw const FormatException('Invalid mini-game content.');
    }
    return {
      'title': title.trim(),
      'introduction': introduction.trim(),
      'instructions': instructions.map((v) => v.trim()).toList(),
      'coverUrl': coverUrl,
      'previewVideoUrl': previewVideoUrl
    };
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'organizationId': organizationId,
        'gameId': gameId,
        'revision': revision,
        ...toFields(),
        'updatedAtMillis': updatedAtMillis
      };
  factory MiniGameContent.fromJson(Map<String, dynamic> d, SessionScope scope) {
    const keys = {
      'schemaVersion',
      'organizationId',
      'gameId',
      'revision',
      'title',
      'introduction',
      'instructions',
      'coverUrl',
      'previewVideoUrl',
      'updatedAtMillis'
    };
    final steps = d['instructions'];
    bool number(Object? v) => v is int && v >= 0 && v <= 9007199254740991;
    if (d.length != keys.length ||
        !keys.every(d.containsKey) ||
        d['schemaVersion'] != 1 ||
        d['organizationId'] != scope.organizationId ||
        !supportedIds.contains(d['gameId']) ||
        !number(d['revision']) ||
        !number(d['updatedAtMillis']) ||
        ((d['revision'] == 0) != (d['updatedAtMillis'] == 0)) ||
        d['title'] is! String ||
        d['introduction'] is! String ||
        d['coverUrl'] is! String ||
        d['previewVideoUrl'] is! String ||
        steps is! List ||
        steps.any((v) => v is! String)) {
      throw const FormatException('Invalid mini-game content response.');
    }
    final content = MiniGameContent(
        organizationId: d['organizationId'],
        gameId: d['gameId'],
        revision: d['revision'],
        updatedAtMillis: d['updatedAtMillis'],
        title: d['title'],
        introduction: d['introduction'],
        instructions: steps.cast<String>(),
        coverUrl: d['coverUrl'],
        previewVideoUrl: d['previewVideoUrl']);
    content.toFields();
    return content;
  }
}

abstract interface class MiniGameContentReader {
  SessionScope get scope;
  bool get current;
  Future<List<MiniGameContent>> load();
}

/// Optional capability exposed by readers which negotiate the implemented registry.
abstract interface class MiniGameContentRegistryStatus {
  bool get expandedRegistryAvailable;
}

/// Only explicit list-negotiation rejection may trigger a legacy read retry.
class MiniGameContentRegistryUnsupported implements Exception {
  const MiniGameContentRegistryUnsupported();
}

abstract interface class MiniGameContentRepository
    implements MiniGameContentReader {
  Future<MiniGameContent> save(
      {required String requestId,
      required int baseRevision,
      required MiniGameContent content});
  Future<String> upload(
      {required String gameId,
      required String kind,
      required String uploadId,
      required Uint8List bytes,
      required String contentType});
}

class MiniGameContentConflict implements Exception {
  const MiniGameContentConflict();
}

class MiniGameContentSessionChanged implements Exception {
  const MiniGameContentSessionChanged();
}

class MiniGameContentUnavailable implements Exception {
  const MiniGameContentUnavailable();
}

class MiniGameContentUploadFailed implements Exception {
  const MiniGameContentUploadFailed({this.code = 'unknown'});
  final String code;
  String get message =>
      'Could not upload mini-game media. Check the file and retry.';
}
