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
    expect(find.text('- member'), findsOneWidget);
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
    expect(find.text('Avg form'), findsOneWidget);
    expect(find.text('To badge'), findsOneWidget);
    expect(find.text('NEXT WITH A COACH'), findsOneWidget);
    expect(find.text('with -'), findsOneWidget);
    await tester.ensureVisible(find.text('Coaches'));
    await tester.tap(find.text('Coaches'));
    await tester.tap(find.text('Bookings'));
    expect(coaches, 1);
    expect(bookings, 1);
    await tester.ensureVisible(find.text('See all goals'));
    expect(find.text('Train 4x per week'), findsOneWidget);
    expect(find.text('Hit 85% average form'), findsOneWidget);
    expect(find.text('3 of 4'), findsNothing);
    expect(find.text('- membership'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
