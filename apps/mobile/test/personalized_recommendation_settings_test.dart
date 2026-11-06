import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/privacy_and_data_settings_screen.dart';
import 'package:gainpath_mobile/features/recommendation/application/recommendation_consent_repository.dart';
import 'package:gainpath_mobile/features/recommendation/presentation/member/personalized_recommendation_settings_screen.dart';
import 'support/recommendation_consent_fixture.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> show(WidgetTester tester,
      {RecommendationConsentRepository? repository,
      bool Function()? current,
      RecommendationConsentNotice? notice = consentNotice}) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildMemberTypographyTheme(),
        home: PersonalizedRecommendationSettingsScreen(
            repository: repository,
            notice: notice,
            isCurrent: current ?? () => true)));
    await tester.pump();
  }

  Finder toggle(RecommendationConsentPurpose purpose) =>
      find.byKey(ValueKey(purpose.name));

  testWidgets(
      'normal preview shows unavailable server state and four disabled off purposes',
      (tester) async {
    await show(tester);
    expect(find.textContaining('Current server state unavailable'),
        findsOneWidget);
    final switches =
        tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches.length, 4);
    expect(switches.every((s) => !s.value && s.onChanged == null), isTrue);
    expect(
        find.textContaining('Camera and backup permissions'), findsOneWidget);
  });

  testWidgets('Privacy and Data opens only the disabled review preview',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildMemberTypographyTheme(),
        home: PrivacyAndDataSettingsScreen(isCurrent: () => true)));
    await tester.ensureVisible(find.text('Personalized Recommendations'));
    await tester.tap(find.text('Personalized Recommendations'));
    await tester.pumpAndSettle();
    expect(
        find.byType(PersonalizedRecommendationSettingsScreen), findsOneWidget);
    expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((s) => s.onChanged == null && !s.value),
        isTrue);
  });

  testWidgets(
      'grant requires notice acknowledgement, cancel writes nothing, confirmed grant reloads server',
      (tester) async {
    var reads = 0, writes = 0;
    Map<String, Object?>? wire;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) async {
          reads++;
          return wire;
        },
        command: (q) async {
          writes++;
          wire = consentWire(revision: 1, granted: true);
          return consentReceipt(q);
        });
    await show(tester, repository: repository);
    await tester.tap(toggle(RecommendationConsentPurpose.exerciseInsights));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm grant'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(toggle(RecommendationConsentPurpose.exerciseInsights));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Confirm grant'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(reads, 2);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .value,
        isTrue);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.externalAiInference))
            .value,
        isFalse);
    expect(find.textContaining('synthetic-notice-1'), findsWidgets);
  });

  testWidgets('revoke has separate confirmation and reloads current state',
      (tester) async {
    Map<String, Object?>? wire = consentWire(revision: 1, granted: true);
    Map<String, Object?>? sent;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) async => wire,
        command: (q) async {
          sent = q;
          wire = consentWire(revision: 2);
          return {...consentReceipt(q), 'purposeRevision': 2};
        });
    await show(tester, repository: repository);
    await tester.tap(toggle(RecommendationConsentPurpose.exerciseInsights));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.textContaining('does not promise deletion'), findsOneWidget);
    expect(sent, isNull);
    await tester.tap(find.text('Confirm revoke'));
    await tester.pumpAndSettle();
    expect(sent?['action'], 'revoke');
    expect(sent?['expectedRevision'], 1);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .value,
        isFalse);
  });

  testWidgets(
      'loading and read failure expose no enabled purpose and retry recovers',
      (tester) async {
    final pending = Completer<Map<String, Object?>?>();
    var first = true;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) => first ? pending.future : Future.value(null),
        command: (_) async => throw StateError('must not write'));
    await show(tester, repository: repository);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((s) => s.onChanged == null),
        isTrue);
    pending.completeError(StateError('provider private detail'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Could not load current consent'), findsOneWidget);
    expect(find.textContaining('provider private detail'), findsNothing);
    first = false;
    await tester.tap(find.text('Reload current state'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .onChanged,
        isNotNull);
  });

  testWidgets(
      'CAS or lost response reloads rather than optimistically granting or retrying',
      (tester) async {
    var reads = 0, writes = 0;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) async {
          reads++;
          return reads == 1 ? null : consentWire(revision: 1, granted: true);
        },
        command: (_) async {
          writes++;
          throw StateError('aborted: private');
        });
    await show(tester, repository: repository);
    await tester.tap(toggle(RecommendationConsentPurpose.exerciseInsights));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Confirm grant'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(writes, 1);
    expect(find.textContaining('Could not verify this change'), findsOneWidget);
    expect(find.textContaining('aborted: private'), findsNothing);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .value,
        isTrue);
  });

  testWidgets(
      'session drift while confirming blocks the mutation and hides prior state',
      (tester) async {
    var current = true, writes = 0;
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => current,
        read: (_) async => null,
        command: (q) async {
          writes++;
          return consentReceipt(q);
        });
    await show(tester, repository: repository, current: () => current);
    await tester.tap(toggle(RecommendationConsentPurpose.exerciseInsights));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    current = false;
    await tester.tap(find.text('Confirm grant'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('Session changed. Return to sign in.'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('unreviewed notice blocks grants but permits explicit revocation',
      (tester) async {
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) async => consentWire(revision: 1, granted: true),
        command: (q) async => consentReceipt(q));
    await show(tester, repository: repository, notice: null);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .onChanged,
        isNotNull);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.externalAiInference))
            .onChanged,
        isNull);
  });

  testWidgets('revoked purpose labels retained history as a previous grant',
      (tester) async {
    final wire = consentWire(revision: 1, granted: true);
    wire['revision'] = 2;
    final purposes = wire['purposes']! as Map<String, Object?>;
    final insight = purposes['exerciseInsights']! as Map<String, Object?>;
    insight.addAll({'granted': false, 'revision': 2, 'revokedAtMillis': 2000});
    final repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) async => wire,
        command: (q) async => consentReceipt(q));
    await show(tester, repository: repository);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .value,
        isFalse);
    expect(find.textContaining('Previous grant history began'), findsOneWidget);
    expect(find.textContaining('no active history scope'), findsOneWidget);
  });

  testWidgets(
      'replacing an injected session transport drops a pending old intent',
      (tester) async {
    final pending = Completer<Map<String, Object?>>();
    Map<String, Object?>? oldRequest;
    var repository = RpcRecommendationConsentRepository(
        scope: consentScope,
        isCurrent: () => true,
        read: (_) async => null,
        command: (q) {
          oldRequest = q;
          return pending.future;
        });
    late StateSetter replace;
    await tester.pumpWidget(MaterialApp(
        theme: buildMemberTypographyTheme(),
        home: StatefulBuilder(builder: (context, setState) {
          replace = setState;
          return PersonalizedRecommendationSettingsScreen(
              repository: repository,
              notice: consentNotice,
              isCurrent: () => true);
        })));
    await tester.pump();
    await tester.tap(toggle(RecommendationConsentPurpose.exerciseInsights));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Confirm grant'));
    await tester.pumpAndSettle();
    expect(oldRequest, isNotNull);
    replace(() {
      repository = RpcRecommendationConsentRepository(
          scope: consentScope,
          isCurrent: () => true,
          read: (_) async => null,
          command: (q) async => consentReceipt(q));
    });
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .onChanged,
        isNotNull);
    pending.complete(consentReceipt(oldRequest!));
    await tester.pumpAndSettle();
    expect(find.textContaining('Change recorded'), findsNothing);
    expect(
        tester
            .widget<SwitchListTile>(
                toggle(RecommendationConsentPurpose.exerciseInsights))
            .value,
        isFalse);
  });

  for (final size in [
    const Size(375, 812),
    const Size(393, 851),
    const Size(851, 393)
  ]) {
    testWidgets(
        'all purpose controls remain reachable at $size with enlarged text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: buildMemberTypographyTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!),
          home:
              PersonalizedRecommendationSettingsScreen(isCurrent: () => true)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
          toggle(RecommendationConsentPurpose.recommendationDelivery));
      expect(tester.takeException(), isNull);
      expect(find.byType(SwitchListTile), findsNWidgets(4));
    });
  }
}
