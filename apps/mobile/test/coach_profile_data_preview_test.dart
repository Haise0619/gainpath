import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_presentation.dart'
    show CoachAccountData;
import 'dart:async';
import 'package:gainpath_domain/identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/identity/application/coach_account_gateway.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_public_profile_preview.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_profile_screen.dart';
import 'support/coach_account_gateway_fake.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'coach_shared_account_test.dart' show draft, frame;

class MetricsAccount extends CoachAccountGatewayFake
    implements CoachAccountMetricsSource {
  Completer<CoachAccountMetrics>? pending;
  int calls = 0;
  bool fail = false;
  @override
  Future<CoachAccountMetrics> loadMetrics() async {
    calls++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return CoachAccountMetrics.fromJson({
      'schemaVersion': 1,
      'records': [
        {'coachId': 'coach', 'averageRating': 4.0, 'reviewCount': 1}
      ],
      'accountSummary': {
        'completedSessions': 23,
        'branches': [
          {'id': 'main', 'name': 'Main gym'}
        ]
      }
    }, 'coach');
  }
}

class PublishedProfileFake extends ProfileFake {
  @override
  Future<PublishedCoachProfile?> loadOwnPublication() async =>
      PublishedCoachProfile(
          id: 'coach',
          fields: CoachProfessionalFields(
              displayName: 'Published Coach',
              specialty: 'Strength',
              bio: 'Published biography',
              specializationTags: ['Strength'],
              yearsExperience: 2,
              consultationFeeMinor: 10000),
          revision: 1,
          sourceRevision: 1,
          status: 'published',
          branchIds: ['main'],
          createdAtMillis: 1,
          updatedAtMillis: 1,
          publishedAtMillis: 1);
}

void main() {
  test(
      'summary parses authoritative metrics and rejects wrong coach or invalid zero rating',
      () {
    final raw = {
      'schemaVersion': 1,
      'records': [
        {'coachId': 'coach', 'averageRating': 4.0, 'reviewCount': 1}
      ],
      'accountSummary': {
        'completedSessions': 23,
        'branches': [
          {'id': 'main', 'name': 'Main gym'}
        ]
      }
    };
    final m = CoachAccountMetrics.fromJson(raw, 'coach');
    expect(m.rating, 4);
    expect(m.sessions, 23);
    expect(m.branch, 'Main gym');
    expect(() => CoachAccountMetrics.fromJson(raw, 'another'),
        throwsFormatException);
    expect(
        () => CoachAccountMetrics.fromJson({
              ...raw,
              'records': [
                {'coachId': 'coach', 'averageRating': 4.0, 'reviewCount': 0}
              ]
            }, 'coach'),
        throwsFormatException);
  });
  testWidgets(
      'loads real metrics and restores original owner preview without booking actions',
      (t) async {
    final account = MetricsAccount();
    await t.pumpWidget(frame(CoachAccountScreen(
        profileRepository: ProfileFake()..profile = draft(),
        accountRepository: account)));
    await t.pumpAndSettle();
    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text('Main gym'), findsOneWidget);
    expect(find.text('1 review'), findsOneWidget);
    await t.tap(find.text('Preview public profile'));
    await t.pumpAndSettle();
    expect(find.byType(CoachProfileScreen), findsOneWidget);
    expect(find.text('Owner draft biography'), findsOneWidget);
    await t.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Book a session'), 250);
    final book = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Book a session'));
    expect(book.onPressed, isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('failed summary shows unavailable and refresh retries',
      (t) async {
    final account = MetricsAccount()..fail = true;
    await t.pumpWidget(frame(CoachAccountScreen(
        profileRepository: ProfileFake()..profile = draft(),
        accountRepository: account)));
    await t.pumpAndSettle();
    expect(
        find.text('Statistics unavailable. Refresh to retry.'), findsOneWidget);
    expect(find.byTooltip('Refresh profile'), findsNothing);
    account.fail = false;
    await t.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await t.pumpAndSettle();
    expect(find.text('4.0'), findsOneWidget);
    expect(account.calls, 2);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'narrow large-text preview switches published and draft with their respective content',
      (t) async {
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(frame(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: CoachAccountScreen(
            profileRepository: PublishedProfileFake()..profile = draft(),
            accountRepository: MetricsAccount()))));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Preview public profile'), 200);
    await Scrollable.ensureVisible(
        t.element(find.text('Preview public profile')),
        alignment: 0.5);
    await t.pumpAndSettle();
    await t.tap(find.text('Preview public profile'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<CoachProfileScreen>(
                find.byType(CoachProfileScreen))
            .coach
            .name,
        'Published Coach');
    expect(
        MediaQuery.textScalerOf(
                t.element(find.byType(CoachProfileScreen)))
            .scale(14),
        28);
    await t.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Draft version'), 150);
    await Scrollable.ensureVisible(
        t.element(find.widgetWithText(ChoiceChip, 'Draft version')),
        alignment: 0.5);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Draft version'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<CoachProfileScreen>(
                find.byType(CoachProfileScreen))
            .coach
            .name,
        'Actual Coach');
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
      'failed metrics preview says unavailable instead of not yet rated',
      (t) async {
    await t.pumpWidget(frame(CoachAccountScreen(
        profileRepository: ProfileFake()..profile = draft(),
        accountRepository: MetricsAccount()..fail = true)));
    await t.pumpAndSettle();
    await t.tap(find.text('Preview public profile'));
    await t.pumpAndSettle();
    expect(find.text('Rating unavailable'), findsOneWidget);
    expect(find.text('Not yet rated'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'preview waits for the initial metrics read rather than freezing zeros',
      (t) async {
    final pending = Completer<CoachAccountMetrics>();
    final account = MetricsAccount()..pending = pending;
    await t.pumpWidget(frame(CoachAccountScreen(
        profileRepository: ProfileFake()..profile = draft(),
        accountRepository: account)));
    await t.pumpAndSettle();
    expect(
        t
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Preview public profile'))
            .onPressed,
        isNull);
    pending.complete(
        const CoachAccountMetrics(rating: 4, reviews: 1, sessions: 23));
    await t.pumpAndSettle();
    await t.tap(find.text('Preview public profile'));
    await t.pumpAndSettle();
    expect(find.text('4.0 · 1 review'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  for (final fee in [null, 0]) {
    testWidgets('historical preview preserves unavailable price for fee $fee',
        (t) async {
      final profile = PublishedCoachProfile(
          id: 'coach',
          fields: CoachProfessionalFields(
              displayName: 'Coach',
              specialty: 'Strength',
              bio: 'Bio',
              specializationTags: ['Strength'],
              yearsExperience: null,
              consultationFeeMinor: fee),
          revision: 1,
          sourceRevision: 1,
          status: 'published',
          branchIds: ['main'],
          createdAtMillis: 1,
          updatedAtMillis: 1,
          publishedAtMillis: 1);
      await t.pumpWidget(MaterialApp(
          home: CoachPublicProfilePreview(
              profile: profile,
              data: const CoachAccountData(
                  name: 'Coach',
                  specialty: 'Strength',
                  directoryLabel: 'Published',
                  reviews: '0'),
              header: const Text('Preview'))));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Price unavailable'), 250);
      expect(find.text('RM 0.00'), findsNothing);
      expect(find.text('Price unavailable'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
