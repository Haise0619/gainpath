import 'dart:convert';
import 'dart:io';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/workout/domain/program_enrollment.dart';

/// One atomic account-private journal. Routine/workout evidence stays in its
/// existing stores and opt-in backup; this file never claims cloud acceptance.
class FileProgramEnrollmentStore implements ProgramEnrollmentStore {
  FileProgramEnrollmentStore(
      {required Directory directory, required this.scope})
      : _directory = Directory('${directory.absolute.path}/workout-programs-v1/'
            '${_segment(scope.organizationId)}/${_segment(scope.userId)}');
  @override
  final SessionScope scope;
  final Directory _directory;
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
  Future<ProgramJournal> _read() async {
    if (!await _file.exists()) return ProgramJournal.empty();
    if (await _file.length() > 16 * 1024 * 1024) {
      throw const FormatException('Program journal too large');
    }
    final data = jsonDecode(await _file.readAsString());
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
        final encoded = jsonEncode({
          'userId': scope.userId,
          'organizationId': scope.organizationId,
          'journal': validated.toJson()
        });
        if (utf8.encode(encoded).length > 16 * 1024 * 1024) {
          throw const FormatException('Program journal too large');
        }
        final pending = File('${_file.path}.pending');
        await pending.writeAsString(encoded, flush: true);
        await pending.rename(_file.path);
      });
}
