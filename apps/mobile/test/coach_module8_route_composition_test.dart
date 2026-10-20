import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/app/mobile_app.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_screen.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'support/coach_account_gateway_fake.dart';
import 'live_booking_composition_test.dart' show Lists;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Firebase home and named Coach route both compose the canonical screen with injected data',
      (tester) async {
    final auth = InMemoryAuthRepository();
    await auth.signIn(
        role: AppRole.coach, email: 'coach@example.test', password: 'fixture');
    var accountCompositions = 0;
    await tester.pumpWidget(GainPathMobileApp(
        authRepository: auth,
        bookingListFactory: (_, __) => Lists(),
        coachProfileFactory: (_, __) => ProfileFake(),
        coachAccountFactory: (_, __) {
          accountCompositions++;
          return CoachAccountGatewayFake();
        }));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountScreen), findsOneWidget);
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pushNamed('/coach');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountScreen), findsOneWidget);
    expect(accountCompositions, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await auth.dispose();
  });
}
