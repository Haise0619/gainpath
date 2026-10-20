import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/client_posture_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class FakeClientPostureRepository implements ClientPostureRepository {
  FakeClientPostureRepository(this.result);
  final ClientPostureResult result;

  @override
  Future<ClientPostureResult> loadPostureHistory(String memberId, {String? bookingId}) async {
    return result;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('displays honest Access Restricted when consent is not granted',
      (tester) async {
    final repo = FakeClientPostureRepository(
      const ClientPostureResult(
        memberId: 'member-1',
        authorized: false,
        sharingStatus: 'consent_not_granted',
        measurementsStatus: 'measurements_pending_validation',
        message: 'Member has not granted cloud workout sharing consent.',
        sessions: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientPostureScreen(
          name: 'Bob Tan',
          memberId: 'member-1',
          repository: repo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bob Tan'), findsOneWidget);
    expect(find.text('Access Restricted'), findsOneWidget);
    expect(
        find.text('Member has not granted cloud workout sharing consent.'),
        findsOneWidget);
    expect(
        find.text(
            'Form history: — · Confirmed booking and authorized cloud measurements required.'),
        findsOneWidget);
  });

  testWidgets('displays Measurements Pending when consent is granted but gate active',
      (tester) async {
    final repo = FakeClientPostureRepository(
      const ClientPostureResult(
        memberId: 'member-1',
        authorized: true,
        sharingStatus: 'granted',
        measurementsStatus: 'measurements_pending_validation',
        message: 'Cloud measurements pending physical model validation gate.',
        sessions: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ClientPostureScreen(
          name: 'Bob Tan',
          memberId: 'member-1',
          repository: repo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bob Tan'), findsOneWidget);
    expect(find.text('Measurements Pending'), findsOneWidget);
    expect(
        find.text(
            'Cloud measurements pending physical model validation gate.'),
        findsOneWidget);
  });
}
