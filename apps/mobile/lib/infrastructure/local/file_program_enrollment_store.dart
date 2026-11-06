import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/program_enrollment.dart';

/// One atomic account-private journal. Routine/workout evidence stays in its
/// existing stores and opt-in backup; this file never claims cloud acceptance.
class FileProgramEnrollmentStore implements ProgramEnrollmentStore {
  FileProgramEnrollmentStore(
      {required Directory directory, required this.scope})
      : _directory = Directory('${directory.absolute.path}/workout-programs-v1/'
            '${_segment(scope.organizationId)}/${_segment(scope.userId)}'),
        _v2Directory =
            Directory('${directory.absolute.path}/workout-programs-v2/'
                '${_segment(scope.organizationId)}/${_segment(scope.userId)}');
  @override
  final SessionScope scope;
  final Directory _directory;
  final Directory _v2Directory;
  static final _queues = <String, Future<void>>{};
  static String _segment(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    await _directory.create(recursive: true);
    final key = await _directory.resolveSymbolicLinks();
    final result = (_queues[key] ?? Future<void>.value()).then((_) async {
      final lock = await File('$key/journal.lock').open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.blockingExclusive);
        return await action();
      } finally {
        await lock.close();
      }
    });
    final tail =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _queues[key] = tail;
    try {
      return await result;
    } finally {
      if (identical(_queues[key], tail)) _queues.remove(key);
    }
  }

  File get _file => File('${_directory.path}/journal.json');
  File get _v2File => File('${_v2Directory.path}/journal.json');
  Future<String?> _legacyDigest() async => await _file.exists()
      ? sha256.convert(await _file.readAsBytes()).toString()
      : null;
  Future<ProgramJournal> _read() async {
    final useV2 = await _v2File.exists();
    final file = useV2 ? _v2File : _file;
    if (!await file.exists()) return ProgramJournal.empty();
    if (await file.length() > 16 * 1024 * 1024) {
      throw const FormatException('Program journal too large');
    }
    final data = jsonDecode(await file.readAsString());
    if (useV2 &&
        (data is! Map || data['legacyDigest'] != await _legacyDigest()))
      throw StateError(
          'Program version-history conflict. Both saved journals are retained.');
    if (data is! Map ||
        data['userId'] != scope.userId ||
        data['organizationId'] != scope.organizationId ||
        data['journal'] is! Map) {
      throw const FormatException('Program journal account mismatch');
    }
    return ProgramJournal.fromJson(
        Map<String, dynamic>.from(data['journal'] as Map));
  }

  @override
  Future<ProgramJournal> load() => _exclusive(_read);
  @override
  Future<void> save(ProgramJournal journal, {required int expectedRevision}) =>
      _exclusive(() async {
        if ((await _read()).revision != expectedRevision ||
            journal.revision != expectedRevision + 1) {
          throw StateError(
              'Program schedule changed in another view. Reload it.');
        }
        final validated = ProgramJournal.fromJson(journal.toJson());
        final useV2 = await _v2File.exists() ||
            validated.enrollments.any((e) => e.program.schemaVersion == 2);
        final file = useV2 ? _v2File : _file;
        await file.parent.create(recursive: true);
        final encoded = jsonEncode({
          if (useV2) 'legacyDigest': await _legacyDigest(),
          'userId': scope.userId,
          'organizationId': scope.organizationId,
          'journal': validated.toJson()
        });
        if (utf8.encode(encoded).length > 16 * 1024 * 1024) {
          throw const FormatException('Program journal too large');
        }
        final pending = File('${file.path}.pending');
        await pending.writeAsString(encoded, flush: true);
        await pending.rename(file.path);
      });
}
