import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/application/coach_availability_cubit.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/live_coach_availability_view.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_coach_schedule_view.dart';
import 'package:gainpath_mobile/app/mobile_app.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession, AppRole;
import 'coach_directory_flow_test.dart' show DriftingCoachAuth, DirectoryFake;
import 'coach_profile_state_test.dart' show ProfileFake;
import 'live_booking_composition_test.dart' show Lists;
import 'support/fitness_profile_fake.dart';

import 'support/coach_availability_fake.dart';

final window = DatedCoachWindow(
    branchId: 'main', startAtMillis: 1792116000000, endAtMillis: 1792117800000);
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test(
      'edit baseline remains immutable; same-intent retry, conflict/discard and fresh removal',
      () async {
    final repo = AvailabilityFake();
    final controller = CoachAvailabilityCubit(
        repository: repo, coachId: 'coach', isCurrent: () => true);
    await controller.loadWeek();
    controller.setWindows([window]);
    expect(controller.state.day!.windows, isEmpty);
    repo.failure = 'unavailable';
    await controller.save();
    await controller.save();
    expect(repo.requests[0], repo.requests[1]);
    repo.failure = 'aborted';
    await controller.save();
    expect(controller.state.conflict, isTrue);
    final count = repo.requests.length;
    await controller.save();
    expect(repo.requests.length, count);
    repo.failure = null;
    await controller.discardAndReload();
    controller.setWindows([window]);
    await controller.save();
    expect(controller.state.day!.revision, 1);
    expect(controller.state.windows, hasLength(1));
    controller.setWindows([]);
    await controller.save();
    expect(repo.stored, isEmpty);
    await controller.close();
  });
  test('late previous-account read cannot restore schedule', () async {
    var current = true;
    final repo = AvailabilityFake()..pending = Completer();
    final controller = CoachAvailabilityCubit(
        repository: repo, coachId: 'coach', isCurrent: () => current);
    final load = controller.loadWeek();
    current = false;
    repo.pending!.complete(repo.context('coach'));
    await load;
    expect(controller.state.context, isNull);
    await controller.close();
  });
  testWidgets(
      'Coach adds and saves a server-boundary window; Member sees persisted schedule and unavailable booking',
      (tester) async {
    final repo = AvailabilityFake();
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Change hours for one date'), 300);
    await tester.ensureVisible(find.text('Change hours for one date'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Change hours for one date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change hours for one date'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asia/Kuala_Lumpur'), findsWidgets);
    await tester.tap(find.text('Add window'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Add'), 250,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    final saveDay = find.widgetWithText(FilledButton, 'Save day');
    await Scrollable.ensureVisible(tester.element(saveDay), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(saveDay);
    await tester.pumpAndSettle();
    expect(repo.stored, hasLength(1));
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachScheduleView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('main'), findsWidgets);
    expect(find.text('Coach schedule; booking unavailable.'), findsOneWidget);
    expect(find.text('Save day'), findsNothing);
    await tester.tap(find.byTooltip('Refresh schedule'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('main'), findsWidgets);
  });
  testWidgets(
      'Firebase Coach reaches dated tab and loses open editor on account drift',
      (tester) async {
    const session = AuthSession(
        userId: 'coach',
        organizationId: 'org',
        email: 'coach@example.test',
        role: AppRole.coach,
        branchIds: ['main']);
    final auth = DriftingCoachAuth(session), repo = AvailabilityFake();
    await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: auth,
        bookingListFactory: (_, __) => Lists(),
        coachProfileFactory: (_, current) => ProfileFake(),
        coachAvailabilityFactory: (_, current) => repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Availability'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Change hours for one date'), 300);
    await tester.ensureVisible(find.text('Change hours for one date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change hours for one date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add window'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
    auth.drift(const AuthSession(
        userId: 'coach',
        organizationId: 'org',
        email: 'coach@example.test',
        role: AppRole.coach,
        branchIds: ['other']));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await auth.dispose();
  });
  testWidgets(
      'Member directory opens schedule by stable Coach ID and logout hides the pushed schedule',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository(), profiles = FakeProfileGateway();
    final session =
        await auth.signIn(email: 'member@example.test', password: 'fixture');
    await profiles.repository(session.scope).save(sampleProfile());
    final repo = AvailabilityFake()..stored = [window];
    await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: auth,
        profileRepositoryFactory: profiles.repository,
        routineLoaderFactory: (_) async => null,
        coachDirectoryFactory: (scope, current) => DirectoryFake(scope),
        coachAvailabilityFactory: (_, current) => repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coaches').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Real contract Coach'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View schedule'));
    await tester.tap(find.text('View schedule'));
    await tester.pumpAndSettle();
    expect(find.text('10:00 GMT+8 – 10:30 GMT+8'), findsOneWidget);
    expect(find.text('Save day'), findsNothing);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('10:00 GMT+8 – 10:30 GMT+8'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('open window editor freezes row mutations until Update or Cancel',
      (tester) async {
    final repo = AvailabilityFake()
      ..stored = [
        window,
        DatedCoachWindow(
            branchId: 'main',
            startAtMillis: 1792117800000,
            endAtMillis: 1792119600000)
      ];
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAvailabilityView(
            repository: repo, coachId: 'coach', isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Change hours for one date'), 300);
    await tester.ensureVisible(find.text('Change hours for one date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change hours for one date'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit-window-1')), 250,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const ValueKey('edit-window-1')));
    await tester.pumpAndSettle();
    for (final control in find
        .byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == 'Remove window')
        .evaluate()) {
      expect((control.widget as IconButton).onPressed, isNull);
    }
    for (final control in find
        .byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Edit window')
        .evaluate()) {
      expect((control.widget as IconButton).onPressed, isNull);
    }
    await tester.ensureVisible(find.text('Update'));
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('remove-window-1')), -250,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const ValueKey('remove-window-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save day'));
    await tester.tap(find.text('Save day'));
    await tester.pumpAndSettle();
    expect(repo.stored.single.toJson(), window.toJson());
  });
}
