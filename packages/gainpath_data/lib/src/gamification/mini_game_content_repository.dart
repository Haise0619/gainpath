import 'dart:convert';
import 'dart:typed_data';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/workout.dart'
    show EquipmentImage, EquipmentVideo;

typedef MiniGameContentCall = Future<Map<String, dynamic>> Function(
    Map<String, dynamic>);

class RemoteMiniGameContentReader
    implements MiniGameContentReader, MiniGameContentRegistryStatus {
  RemoteMiniGameContentReader(
      {required this.scope,
      required bool Function() isCurrent,
      required MiniGameContentCall call})
      : _isCurrent = isCurrent,
        _call = call;
  @override
  final SessionScope scope;
  final bool Function() _isCurrent;
  final MiniGameContentCall _call;
  @override
  bool get expandedRegistryAvailable => _expandedRegistryAvailable;
  bool _expandedRegistryAvailable = true;
  @override
  bool get current => _isCurrent();
  void _check() {
    if (!current) throw const MiniGameContentSessionChanged();
  }

  Future<Map<String, dynamic>> _command(Map<String, dynamic> fields) async {
    _check();
    try {
      final response = await _call({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        ...fields
      });
      _check();
      if (response['schemaVersion'] != 1 ||
          response['organizationId'] != scope.organizationId) {
        throw const FormatException('Mini-game content scope changed.');
      }
      return response;
    } catch (_) {
      _check();
      rethrow;
    }
  }

  @override
  Future<List<MiniGameContent>> load() async {
    late Map<String, dynamic> d;
    var expanded = true;
    try {
      d = await _command({
        'action': 'list',
        'supportedGameIds': MiniGameContent.supportedIds.toList()
      });
    } on MiniGameContentRegistryUnsupported {
      expanded = false;
      d = await _command({'action': 'list'});
    }
    final games = d['games'];
    final expected = expanded
        ? MiniGameContent.supportedIds.toList()
        : [MiniGameContent.supportedId];
    if (d.length != 3 ||
        games is! List ||
        games.length != expected.length ||
        games.any((v) => v is! Map)) {
      throw const FormatException('Supported mini-game content unavailable.');
    }
    final parsed = games
        .map((v) => MiniGameContent.fromJson(
            Map<String, dynamic>.from(v as Map), scope))
        .toList();
    for (var i = 0; i < expected.length; i++) {
      if (parsed[i].gameId != expected[i]) {
        throw const FormatException('Supported mini-game registry changed.');
      }
    }
    _expandedRegistryAvailable = expanded;
    return List.unmodifiable(parsed);
  }
}

class RemoteMiniGameContentRepository extends RemoteMiniGameContentReader
    implements MiniGameContentRepository {
  RemoteMiniGameContentRepository(
      {required super.scope, required super.isCurrent, required super.call});
  @override
  Future<MiniGameContent> save(
      {required String requestId,
      required int baseRevision,
      required MiniGameContent content}) async {
    _check();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(requestId) ||
        baseRevision < 0 ||
        content.organizationId != scope.organizationId ||
        content.revision != baseRevision) {
      throw const FormatException('Mini-game edit baseline changed.');
    }
    final fields = content.toFields();
    final d = await _command({
      'action': 'save',
      'gameId': content.gameId,
      'requestId': requestId,
      'baseRevision': baseRevision,
      ...fields
    });
    if (d.length != 4 || d['confirmed'] != true || d['game'] is! Map) {
      throw const FormatException('Mini-game save was not confirmed.');
    }
    final result = MiniGameContent.fromJson(
        Map<String, dynamic>.from(d['game'] as Map), scope);
    if (result.gameId != content.gameId ||
        result.revision != baseRevision + 1 ||
        jsonEncode(result.toFields()) != jsonEncode(fields)) {
      throw const MiniGameContentConflict();
    }
    return result;
  }

  @override
  Future<String> upload(
      {required String gameId,
      required String kind,
      required String uploadId,
      required Uint8List bytes,
      required String contentType}) async {
    _check();
    if (!MiniGameContent.supportedIds.contains(gameId) ||
        !['cover', 'preview'].contains(kind) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(uploadId)) {
      throw const FormatException('Invalid mini-game media selection.');
    }
    late Uint8List safe;
    if (kind == 'cover') {
      final image = EquipmentImage(bytes);
      if (image.contentType != contentType) {
        throw const FormatException('Image type mismatch.');
      }
      safe = image.bytes;
    } else {
      if (contentType != 'video/mp4' ||
          bytes.isEmpty ||
          bytes.length > MiniGameContent.maxPreviewBytes) {
        throw const FormatException(
            'Choose an MP4 preview no larger than 20 MB.');
      }
      safe = EquipmentVideo(bytes, name: 'preview.mp4').bytes;
    }
    final d = await _command({
      'action': 'uploadMedia',
      'gameId': gameId,
      'kind': kind,
      'uploadId': uploadId,
      'contentType': contentType,
      'dataBase64': base64Encode(safe)
    });
    if (d.length != 5 ||
        d['gameId'] != gameId ||
        d['kind'] != kind ||
        d['url'] is! String ||
        (d['url'] as String).isEmpty ||
        !MiniGameContent.validMediaUrl(d['url'], scope.organizationId, kind,
            gameId: gameId)) {
      throw const FormatException('Mini-game upload was not confirmed.');
    }
    final url = d['url'] as String;
    if (Uri.parse(url).pathSegments.last !=
        'orgs/${scope.organizationId}/miniGameMedia/$gameId/$kind/${scope.userId}/$uploadId') {
      throw const FormatException('Mini-game upload reference changed.');
    }
    return url;
  }
}
