import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/coaching/application/coach_directory_cubit.dart';
import 'coach_directory_flow_test.dart' show published;

class PagedDirectory implements CoachDirectoryRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'o');
  Completer<CoachDirectoryPage<PublishedCoachProfile>>? pending;
  String? failure;
  int loads = 0;
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
      {String? afterId}) async {
    loads++;
    if (failure != null) throw CoachRepositoryException(failure!);
    if (pending != null) return pending!.future;
    return CoachDirectoryPage(
        [published(afterId == null ? 'First page' : 'Fresh page')],
        nextCursor: afterId == null ? 'coach' : null);
  }

  @override
  Future<PublishedCoachProfile?> loadPublished(String coachId) async =>
      published('Detail');
}

void main() {
  test('overlapping refreshes share one read and a later refresh remains fresh',
      () async {
    final repo = PagedDirectory()..pending = Completer();
    final controller =
        CoachDirectoryCubit(repository: repo, isCurrent: () => true);
    final a = controller.refresh(), b = controller.refresh();
    expect(repo.loads, 1);
    repo.pending!.complete(CoachDirectoryPage([published('First')]));
    await Future.wait([a, b]);
    repo.pending = null;
    await controller.refresh();
    expect(repo.loads, 2);
    expect(controller.state.items, isNotEmpty);
    await controller.close();
  });
  test(
      'page append deduplicates stable IDs; refresh and permission loss clear stale entries',
      () async {
    final repo = PagedDirectory();
    final controller =
        CoachDirectoryCubit(repository: repo, isCurrent: () => true);
    await controller.refresh();
    await controller.loadMore();
    expect(controller.state.items.single.fields.bio, 'Fresh page');
    await controller.refresh();
    repo.failure = 'permission-denied';
    await controller.loadMore();
    expect(controller.state.items, isEmpty);
    await controller.close();
  });
  test('late former-account page cannot restore directory entries', () async {
    var current = true;
    final repo = PagedDirectory()..pending = Completer();
    final controller =
        CoachDirectoryCubit(repository: repo, isCurrent: () => current);
    final read = controller.refresh();
    current = false;
    controller.invalidate();
    repo.pending!.complete(CoachDirectoryPage([published('Old account')]));
    await read;
    expect(controller.state.items, isEmpty);
    await controller.close();
  });
}
