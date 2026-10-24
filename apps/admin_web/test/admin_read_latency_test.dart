import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/identity/application/coach_directory_admin_cubit.dart';
import 'package:gainpath_admin_web/features/identity/application/coach_review_alerts_cubit.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coach_review_notification_button.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';

import 'coach_directory_publication_flow_test.dart' show AdminFake;

class _ControlledPages extends AdminFake {
  _ControlledPages()
      : super(SessionScope(userId: 'admin', organizationId: 'org'));

  int accessChecks = 0;
  final draftCalls = <String?>[];
  final publicCalls = <String?>[];
  final drafts = Completer<CoachDirectoryPage<CoachProfessionalProfile>>();
  final publications = Completer<CoachDirectoryPage<PublishedCoachProfile>>();

  @override
  Future<bool> canManageDirectory() async {
    accessChecks++;
    return allowed;
  }

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
      {String? afterId}) {
    draftCalls.add(afterId);
    return drafts.future;
  }

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
      {String? afterId}) {
    publicCalls.add(afterId);
    return publications.future;
  }
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _ControlledReviews extends AdminFake {
  _ControlledReviews()
      : super(SessionScope(userId: 'admin', organizationId: 'org'));
  final calls = <String>[];
  final responses =
      List.generate(5, (_) => Completer<CoachPublicationReview>());
  List<CoachProfessionalProfile> get candidates => List.generate(
      5,
      (i) => CoachProfessionalProfile(
          id: 'coach-$i',
          fields: fields,
          revision: 1,
          createdAtMillis: 1,
          updatedAtMillis: i + 2));

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
          {String? afterId}) async =>
      CoachDirectoryPage(candidates);

  @override
  Future<CoachPublicationReview> loadReview(String coachId) {
    calls.add(coachId);
    return responses[int.parse(coachId.split('-').last)].future;
  }

  void complete(int i) => responses[i].complete(CoachPublicationReview(
      coachId: 'coach-$i',
      draft: candidates[i],
      publication: null,
      branchIds: ['main'],
      targetMembershipEligible: true));
}

class _TimedReviews extends _ControlledReviews {
  @override
  Future<bool> canManageDirectory() =>
      Future.delayed(const Duration(milliseconds: 20), () => allowed);
  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
          {String? afterId}) =>
      Future.delayed(const Duration(milliseconds: 120),
          () => CoachDirectoryPage(candidates));
  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
          {String? afterId}) =>
      Future.delayed(
          const Duration(milliseconds: 80), () => CoachDirectoryPage([]));
  @override
  Future<CoachPublicationReview> loadReview(String coachId) => Future.delayed(
      const Duration(milliseconds: 60),
      () => CoachPublicationReview(
          coachId: coachId,
          draft: candidates[int.parse(coachId.split('-').last)],
          publication: null,
          branchIds: ['main'],
          targetMembershipEligible: true));
}

class _PaginatedReviews extends AdminFake {
  _PaginatedReviews()
      : super(SessionScope(userId: 'admin', organizationId: 'org')) {
    seed();
  }
  bool repeatCursor = false;
  final draftCursors = <String?>[];
  final publicCursors = <String?>[];

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
      {String? afterId}) async {
    draftCursors.add(afterId);
    return CoachDirectoryPage(afterId == null ? [] : [draft!],
        nextCursor: afterId == null || repeatCursor ? 'draft-next' : null);
  }

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
      {String? afterId}) async {
    publicCursors.add(afterId);
    return CoachDirectoryPage([],
        nextCursor: afterId == null ? 'public-next' : null);
  }
}

void main() {
  test('directory coalesces overlapping refreshes and starts both page reads',
      () async {
    final repository = _ControlledPages();
    final cubit = CoachDirectoryAdminCubit(repository);
    addTearDown(cubit.close);

    final first = cubit.refresh();
    final duplicate = cubit.refresh();
    await _flush();
    // Both independent reads start before either network response completes.
    expect(repository.draftCalls, [null]);
    expect(repository.publicCalls, [null]);
    expect(repository.accessChecks, 1);
    expect(cubit.state.loading, isTrue);

    repository.drafts.complete(CoachDirectoryPage([]));
    repository.publications.complete(CoachDirectoryPage([]));
    await Future.wait([first, duplicate]);
    expect(cubit.state.allowed, isTrue);
    expect(cubit.state.loading, isFalse);

    // Coalescing ends with the response: explicit refresh reads again.
    await cubit.refresh();
    expect(repository.draftCalls, [null, null]);
    expect(repository.publicCalls, [null, null]);
    expect(repository.accessChecks, 2);
  });

  test('alerts start independent draft and publication pagination together',
      () async {
    final repository = _ControlledPages();
    final cubit = CoachReviewAlertsCubit(repository);
    addTearDown(cubit.close);

    final pending = cubit.refresh();
    await _flush();
    expect(repository.draftCalls, [null]);
    expect(repository.publicCalls, [null]);
    repository.drafts.complete(CoachDirectoryPage([]));
    repository.publications.complete(CoachDirectoryPage([]));
    await pending;
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.error, isNull);
    expect(repository.accessChecks, 2);
  });

  test('alerts review four candidates together, then retain newest-first order',
      () async {
    final repository = _ControlledReviews();
    final cubit = CoachReviewAlertsCubit(repository);
    addTearDown(cubit.close);
    final pending = cubit.refresh();
    await _flush();
    expect(repository.calls, ['coach-0', 'coach-1', 'coach-2', 'coach-3']);
    for (var i = 0; i < 4; i++) {
      repository.complete(i);
    }
    await _flush();
    expect(repository.calls, hasLength(5));
    repository.complete(4);
    await pending;
    expect(cubit.state.items.map((item) => item.coachId),
        ['coach-4', 'coach-3', 'coach-2', 'coach-1', 'coach-0']);
  });

  test('alerts discard parallel results after Admin authorization is revoked',
      () async {
    final repository = _ControlledReviews();
    final cubit = CoachReviewAlertsCubit(repository);
    addTearDown(cubit.close);
    final pending = cubit.refresh();
    await _flush();
    repository.allowed = false;
    for (var i = 0; i < 5; i++) {
      repository.complete(i);
    }
    await pending;
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.error, isNotNull);
  });

  test('alerts preserve independent cursors and stop repeated-page loops',
      () async {
    final repository = _PaginatedReviews();
    final cubit = CoachReviewAlertsCubit(repository);
    addTearDown(cubit.close);
    await cubit.refresh();
    expect(repository.draftCursors, [null, 'draft-next']);
    expect(repository.publicCursors, [null, 'public-next']);
    expect(cubit.state.items.single.coachId, 'coach');

    repository.repeatCursor = true;
    await cubit.refresh();
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.error, isNotNull);
    repository.repeatCursor = false;
    await cubit.refresh();
    expect(cubit.state.items.single.coachId, 'coach');
  });

  test('alerts fail closed when one review fails and can retry afterward',
      () async {
    final repository = _ControlledReviews();
    final cubit = CoachReviewAlertsCubit(repository);
    addTearDown(cubit.close);
    final pending = cubit.refresh();
    await _flush();
    repository.responses[1]
        .completeError(const CoachRepositoryException('permission-denied'));
    for (final i in [0, 2, 3]) {
      repository.complete(i);
    }
    await pending;
    expect(repository.calls, hasLength(4));
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.error, isNotNull);
    repository.responses[1] = Completer<CoachPublicationReview>();
    repository.complete(1);
    repository.complete(4);
    await cubit.refresh();
    expect(cubit.state.items, hasLength(5));
    expect(cubit.state.error, isNull);
  });

  test('closing alerts stops later review batches and late results', () async {
    final repository = _ControlledReviews();
    final cubit = CoachReviewAlertsCubit(repository);
    final pending = cubit.refresh();
    await _flush();
    await cubit.close();
    for (var i = 0; i < 4; i++) {
      repository.complete(i);
    }
    await pending;
    expect(repository.calls, hasLength(4));
    expect(cubit.state.items, isEmpty);
  });

  testWidgets('Coach alert bell renders five candidates within 280 virtual ms',
      (tester) async {
    await tester.pumpWidget(
        RepositoryProvider<CoachProfileAdminRepository>.value(
            value: _TimedReviews(),
            child: MaterialApp(
                home: Scaffold(
                    appBar: AppBar(actions: [
              CoachReviewNotificationButton(onOpenCoach: (_) {})
            ])))));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
