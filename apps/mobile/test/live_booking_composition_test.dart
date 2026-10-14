import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/di/coach_profile_factory.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_confirmed_screen.dart';
import 'coach_directory_flow_test.dart' show DirectoryFake, DriftingCoachAuth;
import 'live_booking_cubit_test.dart' show Options, Writer;
import 'firebase_booking_repository_test.dart' show pageJson;

class Lists implements BookingListRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  @override
  Future<BookingPage> load(
          {String? coachId,
          String? firstLocalDate,
          int? dayCount,
          BookingCursor? cursor}) async =>
      BookingPage.fromJson(pageJson());
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'guarded Member directory to pending receipt and own persisted list; drift clears routes',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const session = AuthSession(
        userId: 'member',
        organizationId: 'org',
        branchIds: ['branch'],
        email: 'fixture@example.test',
        role: AppRole.member);
    final auth = DriftingCoachAuth(session);
    final bloc = AuthBloc(repository: auth);
    await tester.pump();
    expect(bloc.state.status, AuthStatus.signedIn);
    var created = 0;
    final writer = Writer();
    await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: MaterialApp(
            home: buildFirebaseCoachDirectory(session,
                factory: (scope, _) => DirectoryFake(scope),
                bookingFactory: (_, __) {
                  created++;
                  return (options: Options(), writer: writer);
                },
                bookingListFactory: (_, __) => Lists()))));
    await tester.pumpAndSettle();
    expect(created, 0);
    expect(find.text('My bookings'), findsOneWidget);
    await tester.tap(find.text('Real contract Coach'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose time'));
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    expect(created, 1);
    await tester.tap(find.text('08:00 GMT+8 – 08:30 GMT+8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request pending hold'));
    await tester.pumpAndSettle();
    expect(find.text('Retry same request'), findsOneWidget);
    await tester.tap(find.text('Retry same request'));
    await tester.pumpAndSettle();
    expect(find.text('Booking booking'), findsOneWidget);
    expect(find.byType(BookingConfirmedScreen), findsNothing);
    await tester.tap(find.text('View persisted bookings'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Pending hold — time elapsed; awaiting server expiry.'),
        findsOneWidget);
    expect(
        find.textContaining('Coach: coach · Member: member'), findsOneWidget);
    auth.drift(const AuthSession(
        userId: 'member',
        organizationId: 'org',
        branchIds: ['changed'],
        email: 'fixture@example.test',
        role: AppRole.member));
    await tester.pumpAndSettle();
    expect(find.text('Booking booking'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await bloc.close();
      await auth.dispose();
    });
  });
  testWidgets(
      'My bookings remains reachable from empty directory without creating options SDK',
      (tester) async {
    const session = AuthSession(
        userId: 'member',
        organizationId: 'org',
        email: 'fixture@example.test',
        role: AppRole.member);
    final auth = DriftingCoachAuth(session);
    final bloc = AuthBloc(repository: auth);
    await tester.pump();
    expect(bloc.state.status, AuthStatus.signedIn);
    final directory = DirectoryFake(session.scope)..profile = null;
    await tester.pumpWidget(BlocProvider.value(
        value: bloc,
        child: MaterialApp(
            home: buildFirebaseCoachDirectory(session,
                factory: (_, __) => directory,
                bookingFactory: (_, __) => throw StateError('Must remain lazy'),
                bookingListFactory: (_, __) => Lists()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Booking booking'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await bloc.close();
      await auth.dispose();
    });
  });
}
