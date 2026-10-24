import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'coach_directory_publication_flow_test.dart' show AdminFake;

class ScheduleFake implements CoachAvailabilityRepository {
  ScheduleFake(this.scope);
  @override
  final SessionScope scope;
  @override
  Future<CoachAvailabilityContext> load(
          {required String coachId,
          String? firstLocalDate,
          int dayCount = 7}) async =>
      CoachAvailabilityContext(
          coachId: coachId,
          serverNowMillis: 1,
          todayLocalDate: '2026-10-15',
          timeZone: 'Asia/Kuala_Lumpur',
          assignedBranchIds: [
            'main'
          ],
          days: [
            CoachAvailabilityDay(localDate: '2026-10-16', windows: [
              DatedCoachWindow(
                  branchId: 'main',
                  startAtMillis: 1792116000000,
                  endAtMillis: 1792117800000)
            ], displayTimes: const [
              CoachTimeBoundary(atMillis: 1792116000000, label: '10:00 GMT+8'),
              CoachTimeBoundary(atMillis: 1792117800000, label: '10:30 GMT+8')
            ])
          ]);
  @override
  Future<CoachAvailabilitySaveResult> save(
          {required CoachAvailabilityDay baseline,
          required CoachAvailabilityContext context,
          required List<DatedCoachWindow> windows,
          required String requestId}) =>
      throw StateError('Admin UI must never save availability.');
}

class _EmptyPhotoAccount extends Fake implements AdminAccountContactRepository {
  @override
  Future<Uint8List?> loadCurrentPhoto() async => null;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Admin review opens scoped read-only schedule and sign-out hides its route',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository();
    final session = await auth.signIn(
        role: AppRole.admin, email: 'admin@example.test', password: 'fixture');
    await tester.pumpWidget(GainPathAdminWebApp.injected(
        authRepository: auth,
        accountContactFactory: (_, __) => _EmptyPhotoAccount(),
        coachRepositoryFactory: (_, current) =>
            AdminFake(session.scope)..seed(),
        coachAvailabilityFactory: (scope, current) => ScheduleFake(scope)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coaches').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View schedule'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('View schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Organization time: Asia/Kuala_Lumpur'), findsOneWidget);
    expect(find.text('10:00 GMT+8 – 10:30 GMT+8'), findsOneWidget);
    expect(find.text('Save day'), findsNothing);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('10:00 GMT+8 – 10:30 GMT+8'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
