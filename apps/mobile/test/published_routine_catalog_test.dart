import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/workout/application/published_routine_catalog_cubit.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_catalog_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';

PublishedRoutine fixture(String id, {String? title}) => PublishedRoutine(
        id: id,
        sourceBlueprintId: 'blueprint-$id',
        title: title ?? id,
        estimatedMinutes: 30,
        exercises: const [
          PublishedRoutineExercise(
              exerciseId: 'unsupported-fixture',
              dayNumber: 1,
              name: 'Fixture exercise',
              category: 'Core',
              sets: 2,
              reps: 5,
              cue: '',
              imageUrl: '',
              muscleGroup: 'Core')
        ]);

class Catalog implements PublishedRoutineCatalogRepository {
  Catalog(this.scope);
  @override
  final SessionScope scope;
  PublishedRoutinePage page =
      PublishedRoutinePage([fixture('a'), fixture('b')]);
  final byId = <String, PublishedRoutine>{};
  Completer<PublishedRoutinePage>? pending;
  Object? error;
  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) async {
    if (error != null) throw error!;
    return pending?.future ?? page;
  }

  @override
  Future<PublishedRoutine?> loadById(String id) async => byId[id];
}

void main() {
  late SessionScope scope;
  late Catalog repository;
  late SessionScope? active;
  late PublishedRoutineCatalogCubit cubit;
  setUp(() {
    scope = SessionScope(userId: 'member', organizationId: 'org');
    active = scope;
    repository = Catalog(scope);
    cubit = PublishedRoutineCatalogCubit(
        repository: repository, activeScope: () => active);
  });
  tearDown(() async => cubit.close());
  test('discovers two IDs, chooses specific routine and refreshes its data',
      () async {
    await cubit.refresh();
    expect(cubit.state.items.map((r) => r.id), ['a', 'b']);
    expect(cubit.state.selected?.id, 'a');
    cubit.select('b');
    repository.page =
        PublishedRoutinePage([fixture('a'), fixture('b', title: 'Updated')]);
    await cubit.refresh();
    expect(cubit.state.selected?.id, 'b');
    expect(cubit.state.selected?.title, 'Updated');
  });
  test(
      'selected item outside first page is revalidated; withdrawn item is cleared',
      () async {
    await cubit.refresh();
    cubit.select('b');
    repository.page = PublishedRoutinePage([fixture('a')], nextCursor: 'a');
    repository.byId['b'] = fixture('b', title: 'Still published');
    await cubit.refresh();
    expect(cubit.state.selected?.title, 'Still published');
    repository.byId.clear();
    await cubit.refresh();
    expect(cubit.state.selected, isNull);
    expect(cubit.state.items.single.id, 'a');
  });
  test('bounded next page appends without changing selection', () async {
    repository.page = PublishedRoutinePage([fixture('a')], nextCursor: 'a');
    await cubit.refresh();
    repository.page = PublishedRoutinePage([fixture('b')]);
    await cubit.loadMore();
    expect(cubit.state.items.map((r) => r.id), ['a', 'b']);
    expect(cubit.state.selected?.id, 'a');
    expect(cubit.state.nextCursor, isNull);
  });
  test('account change clears selection and late response cannot restore it',
      () async {
    await cubit.refresh();
    repository.pending = Completer();
    final request = cubit.refresh();
    active = SessionScope(userId: 'other', organizationId: 'org');
    cubit.accountChanged();
    repository.pending!
        .complete(PublishedRoutinePage([fixture('old-account')]));
    await request;
    expect(cubit.state.selected, isNull);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.status, CatalogStatus.unavailable);
  });
  test(
      'newer refresh wins, organization drift and errors cannot expose old selection',
      () async {
    repository.pending = Completer();
    final old = cubit.refresh();
    final pending = repository.pending!;
    repository.pending = null;
    await cubit.refresh();
    pending.complete(PublishedRoutinePage([fixture('late')]));
    await old;
    expect(cubit.state.selected?.id, 'a');
    repository.error = StateError('private-media-detail');
    await cubit.refresh();
    expect(cubit.state.selected, isNull);
    expect(cubit.state.status, CatalogStatus.error);
    expect(cubit.state.message, isNot(contains('private-media-detail')));
    active = SessionScope(userId: 'member', organizationId: 'elsewhere');
    cubit.accountChanged();
    expect(cubit.state.items, isEmpty);
  });
  test('empty catalog is truthful; unknown ID cannot become a selection',
      () async {
    repository.page = PublishedRoutinePage([]);
    await cubit.refresh();
    expect(cubit.state.status, CatalogStatus.empty);
    cubit.select('unknown');
    expect(cubit.state.selected, isNull);
  });
}
