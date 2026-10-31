import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_profile_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('connected profile opens app-composed metrics and membership',
      (tester) async {
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider.value(
      value: auth,
      child: MaterialApp(
        home: MemberProfileScreen(
          liveSession: const AuthSession(
              email: 'member@example.test', role: AppRole.member),
          bodyMetricsBuilder: (_) =>
              const Scaffold(body: Text('Metrics destination')),
          membershipBuilder: (_) =>
              const Scaffold(body: Text('Membership destination')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    for (final entry in {
      'Body metrics': 'Metrics destination',
      'Membership': 'Membership destination',
    }.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      Navigator.of(tester.element(find.text(entry.value))).pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected profile retains badge and menus with missing fields',
      (tester) async {
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    addTearDown(auth.close);
    await tester.pumpWidget(BlocProvider.value(
      value: auth,
      child: const MaterialApp(
          home: MemberProfileScreen(
        liveSession:
            AuthSession(email: 'member@example.test', role: AppRole.member),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Membership unavailable'), findsOneWidget);
    expect(find.text('- member'), findsNothing);
    expect(find.text('member@example.test'), findsOneWidget);
    expect(find.text('Physical profile'), findsOneWidget);
    expect(find.text('Fitness goals'), findsOneWidget);
    expect(find.text('Premium member'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'connected home preserves mock cards and real navigation callbacks',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var coaches = 0;
    var bookings = 0;
    await tester.pumpWidget(MaterialApp(
      home: MemberHomeScreen(
        liveSession: const AuthSession(
            email: 'member@example.test', role: AppRole.member),
        onOpenCoaches: () => coaches++,
        onOpenBookings: () => bookings++,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text("TODAY'S SESSION"), findsOneWidget);
    expect(find.text("THIS WEEK"), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    // Unmeasured and unsupported placeholder cards are removed in live mode without data
    expect(find.text('Avg form'), findsNothing);
    expect(find.text('To badge'), findsNothing);
    expect(find.text('with -'), findsNothing);
    expect(find.text('- membership'), findsNothing);

    // Bookings and Coaches are directly accessible on the Quick Access grid
    await tester.ensureVisible(find.text('Coaches'));
    await tester.tap(find.text('Coaches'));
    await tester.tap(find.text('Bookings'));
    expect(coaches, 1);
    expect(bookings, 1);

    expect(tester.takeException(), isNull);
  });
}
