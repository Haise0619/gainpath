import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession, AppRole;
import 'package:gainpath_mobile/app/notifications/member_notifications_screen.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/member_recommendation_sheet.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'member_recommendation_repository_test.dart' show memberDetail;

const member = AuthSession(
    userId: 'm1',
    organizationId: 'gym1',
    email: 'member@example.invalid',
    role: AppRole.member,
    branchIds: ['main']);

class InboxFake implements Module9Repository {
  final calls = <String?>[];
  final readCalls = <String>[];
  @override
  Stream<void> watchInbox() => const Stream.empty();
  @override
  Future<NoticePage> loadInbox({String? afterId}) async {
    calls.add(afterId);
    return afterId == null
        ? NoticePage([
            MemberNotice(
                id: 'booking',
                title: 'Booking confirmed',
                message: 'Your current booking.',
                read: false,
                createdAt: DateTime(2026, 11, 2),
                bookingId: 'b1')
          ], 'older')
        : NoticePage([
            MemberNotice(
                id: 'rec',
                title: 'Meet your Coach',
                message: 'Support for your next learning step.',
                read: false,
                createdAt: DateTime(2026, 11, 1),
                recommendation: RecommendationNotice.parse({
                  'schemaVersion': 1,
                  'recommendationId': 'r1',
                  'kind': 'trainer',
                  'state': 'available',
                  'expiresAtMillis': 4102444800000,
                  'target': memberDetail()['target']
                }, 'gym1'))
          ], null);
  }

  @override
  Future<void> markRead(String id) async {
    readCalls.add(id);
  }

  @override
  Future<CoachSharing> loadSharing() async => const CoachSharing(false, 0);
  @override
  Future<CoachSharing> saveSharing(bool enabled, int expectedRevision) async =>
      CoachSharing(enabled, expectedRevision + 1);
  @override
  Future<CoachReport> loadPerformance() => throw UnimplementedError();
}

Widget host(Widget child, {double textScale = 1}) => MaterialApp(
    theme: AppTheme.build(),
    home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child));
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('unavailable normal composition never seeds demo notices',
      (tester) async {
    await tester
        .pumpWidget(host(MemberNotificationsScreen(isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(
        find.text('Notifications are currently unavailable.'), findsOneWidget);
    expect(find.text('Public holiday gym hours'), findsNothing);
    expect(find.text('Synthetic local preview'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'filtered empty inbox still reaches older recommendations and keeps booking notices',
      (tester) async {
    final inbox = InboxFake();
    await tester.pumpWidget(host(MemberNotificationsScreen(
        session: member, isCurrent: () => true, module9Repository: inbox)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recommendations'));
    await tester.tap(find.text('Recommendations'));
    await tester.pumpAndSettle();
    expect(find.text('No recommendations yet.'), findsOneWidget);
    await tester.tap(find.text('Load older notifications'));
    await tester.pumpAndSettle();
    expect(inbox.calls, [null, 'older']);
    expect(find.text('Meet your Coach'), findsOneWidget);
    await tester.ensureVisible(find.text('All'));
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Booking confirmed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'read ack and dismiss are separate durable commands and no identifiers appear',
      (tester) async {
    final actions = <String>[];
    var detail = memberDetail();
    Completer<Map<String, Object?>>? pending;
    final repo = RpcMemberRecommendationRepository(
        scope: member.scope,
        isCurrent: () => true,
        invoke: (request) async {
          final action = request['action'] as String;
          actions.add(action);
          if (action == 'read') {
            detail = {...detail, 'readAtMillis': 1200, 'revision': 2};
          }
          if (action == 'acknowledge') {
            pending = Completer<Map<String, Object?>>();
            return pending!.future;
          }
          if (action == 'dismiss') {
            detail = {
              ...detail,
              'dismissedAtMillis': 1400,
              'revision': 4,
              'state': 'dismissed',
              'target': null
            };
          }
          return detail;
        });
    await tester.pumpWidget(host(MemberRecommendationSheet(
        recommendationId: 'r1',
        repository: repo,
        isCurrent: () => true,
        onOpenTarget: (_, __) async {})));
    await tester.pumpAndSettle();
    expect(actions, ['get', 'read']);
    expect(find.text('Acknowledged'), findsNothing);
    expect(find.text('Synthetic local preview'), findsOneWidget);
    expect(find.text('r1'), findsNothing);
    expect(find.text('c1'), findsNothing);
    await tester.ensureVisible(find.text('Acknowledge'));
    await tester.tap(find.text('Acknowledge'));
    await tester.pump();
    expect(find.text('Acknowledged'), findsNothing);
    detail = {...detail, 'acknowledgedAtMillis': 1300, 'revision': 3};
    pending!.complete(detail);
    await tester.pumpAndSettle();
    expect(find.text('Acknowledged'), findsOneWidget);
    await tester.ensureVisible(find.text('Dismiss recommendation'));
    await tester.tap(find.text('Dismiss recommendation'));
    await tester.pumpAndSettle();
    expect(actions, ['get', 'read', 'acknowledge', 'dismiss']);
    expect(find.text('Recommendation dismissed.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed read does not expose fake read or acknowledgment success',
      (tester) async {
    final repo = RpcMemberRecommendationRepository(
        scope: member.scope,
        isCurrent: () => true,
        invoke: (request) async {
          if (request['action'] == 'read') {
            throw StateError('private backend details');
          }
          return memberDetail();
        });
    await tester.pumpWidget(host(MemberRecommendationSheet(
        recommendationId: 'r1', repository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open'), findsOneWidget);
    expect(find.text('Coach Alex'), findsNothing);
    expect(find.textContaining('private backend'), findsNothing);
    expect(find.text('Acknowledged'), findsNothing);
  });
  testWidgets(
      'lost acknowledgment response retains command for safe explicit retry',
      (tester) async {
    final commands = <String>[];
    var fail = true;
    final repo = RpcMemberRecommendationRepository(
        scope: member.scope,
        isCurrent: () => true,
        invoke: (request) async {
          if (request['action'] == 'acknowledge') {
            commands.add(request['commandId'] as String);
            if (fail) {
              fail = false;
              throw StateError('offline');
            }
            return {
              ...memberDetail(),
              'readAtMillis': 1200,
              'revision': 3,
              'acknowledgedAtMillis': 1300
            };
          }
          return {...memberDetail(), 'readAtMillis': 1200, 'revision': 2};
        });
    await tester.pumpWidget(host(MemberRecommendationSheet(
        recommendationId: 'r1', repository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Acknowledge'));
    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();
    expect(find.text('Acknowledged'), findsNothing);
    expect(find.textContaining('not confirmed'), findsOneWidget);
    await tester.ensureVisible(find.text('Retry response'));
    await tester.tap(find.text('Retry response'));
    await tester.pumpAndSettle();
    expect(commands.length, 2);
    expect(commands.first, commands.last);
    expect(find.text('Acknowledged'), findsOneWidget);
  });
  for (final size in [
    const Size(393, 851),
    const Size(375, 812),
    const Size(851, 393)
  ]) {
    testWidgets(
        'purple detail fits ${size.width} wide with large accessible text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = RpcMemberRecommendationRepository(
          scope: member.scope,
          isCurrent: () => true,
          invoke: (_) async => {...memberDetail(), 'readAtMillis': 1200});
      await tester.pumpWidget(host(
          MemberRecommendationSheet(
              recommendationId: 'r1',
              repository: repo,
              isCurrent: () => true,
              onOpenTarget: (_, __) async {}),
          textScale: 2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View Coach'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final semantics = tester.ensureSemantics();
      expect(find.byTooltip('Close recommendation'), findsOneWidget);
      expect(
          tester
              .getSize(find.ancestor(
                  of: find.text('View Coach'),
                  matching: find.byWidgetPredicate((w) => w is FilledButton)))
              .height,
          greaterThanOrEqualTo(48));
      semantics.dispose();
    });
  }
  for (final state in [
    'expired',
    'withdrawn',
    'unavailable',
    'dismissed',
    'not_delivered'
  ]) {
    testWidgets('$state disables destination and offers safe Coach browsing',
        (tester) async {
      var browsed = false;
      final repo = RpcMemberRecommendationRepository(
          scope: member.scope,
          isCurrent: () => true,
          invoke: (_) async => memberDetail(state: state));
      await tester.pumpWidget(host(MemberRecommendationSheet(
          recommendationId: 'r1',
          repository: repo,
          isCurrent: () => true,
          onBrowseCoaches: () => browsed = true)));
      await tester.pumpAndSettle();
      expect(find.text('View Coach'), findsNothing);
      expect(find.text('Acknowledge'), findsNothing);
      await tester.ensureVisible(find.text('Browse Coaches'));
      await tester.tap(find.text('Browse Coaches'));
      expect(browsed, true);
    });
  }
  testWidgets(
      'denied acknowledgment clears protected context before revalidation',
      (tester) async {
    final repo = RpcMemberRecommendationRepository(
        scope: member.scope,
        isCurrent: () => true,
        invoke: (request) async {
          if (request['action'] == 'acknowledge') {
            throw StateError('permission-denied');
          }
          return {...memberDetail(), 'readAtMillis': 1200};
        });
    await tester.pumpWidget(host(MemberRecommendationSheet(
        recommendationId: 'r1',
        repository: repo,
        isCurrent: () => true,
        onOpenTarget: (_, __) async {})));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Acknowledge'));
    await tester.tap(find.text('Acknowledge'));
    await tester.pumpAndSettle();
    expect(find.text('Coach Alex'), findsNothing);
    expect(find.text('Squat'), findsNothing);
    expect(find.text('Practice with verified guidance.'), findsNothing);
    expect(find.text('View Coach'), findsNothing);
    expect(find.text('Acknowledge'), findsNothing);
    expect(find.text('Retry response'), findsOneWidget);
  });
  for (final path in [
    'orgs/gym1/coachProfilePhotos/c1/current.png',
    'orgs/foreign/coachProfilePhotos/c1/other.png'
  ]) {
    testWidgets('photo builder requires a current scoped source path $path',
        (tester) async {
      var builds = 0;
      final repo = RpcMemberRecommendationRepository(
          scope: member.scope,
          isCurrent: () => true,
          invoke: (_) async =>
              {...memberDetail(), 'readAtMillis': 1200, 'photoPath': path});
      await tester.pumpWidget(host(MemberRecommendationSheet(
          recommendationId: 'r1',
          repository: repo,
          isCurrent: () => true,
          scopedPhotoBuilder: (_, detail) {
            builds++;
            return const SizedBox(
                height: 144, child: Text('Current scoped Coach photo'));
          })));
      await tester.pumpAndSettle();
      expect(builds, path.contains('/foreign/') ? 0 : greaterThan(0));
      expect(find.text('Current scoped Coach photo'),
          path.contains('/foreign/') ? findsNothing : findsOneWidget);
    });
  }
  testWidgets(
      'an expired delivered recommendation can still be dismissed safely',
      (tester) async {
    final actions = <String>[];
    final repo = RpcMemberRecommendationRepository(
        scope: member.scope,
        isCurrent: () => true,
        invoke: (request) async {
          actions.add(request['action'] as String);
          return {
            ...memberDetail(
                state:
                    request['action'] == 'dismiss' ? 'dismissed' : 'expired'),
            'exerciseLabel': null,
            'objective': null,
            'explanations': <String>[],
            if (request['action'] == 'dismiss') 'dismissedAtMillis': 1400
          };
        });
    await tester.pumpWidget(host(MemberRecommendationSheet(
        recommendationId: 'r1', repository: repo, isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('View Coach'), findsNothing);
    expect(find.text('Acknowledge'), findsNothing);
    await tester.ensureVisible(find.text('Dismiss recommendation'));
    await tester.tap(find.text('Dismiss recommendation'));
    await tester.pumpAndSettle();
    expect(actions, ['get', 'dismiss']);
    expect(find.text('Recommendation dismissed.'), findsOneWidget);
  });
}
