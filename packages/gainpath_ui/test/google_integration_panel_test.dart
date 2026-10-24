import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/src/google_integration_panel.dart';

void main() {
  testWidgets('shared panel reports automatic delivery and uncertain email without a resend action', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GoogleIntegrationPanel(repository: _Automatic(), admin: true, coachId: 'coach', loadCoaches: () async => {'coach': 'Coach'})))));
    await tester.pumpAndSettle();
    expect(find.text('Automatic delivery: Enabled for approved test recipients'), findsOneWidget);
    expect(find.textContaining('Automatic delivery needs Admin review'), findsOneWidget);
    expect(find.textContaining('Email: Outcome uncertain'), findsOneWidget);
    expect(find.text('Retry email'), findsNothing);
  });
  testWidgets(
      'Coach sees gym-managed status without connect or delivery actions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: GoogleIntegrationPanel(
                repository: DisconnectedGoogleIntegrationRepository(),
                coachId: 'coach'))));
    await tester.pumpAndSettle();
    expect(find.text('Managed by your gym'), findsOneWidget);
    expect(find.text('Connect gym account'), findsNothing);
    expect(find.textContaining('Availability and bookings stay in GainPath'),
        findsOneWidget);
  });
  testWidgets('Admin confirms before disconnect', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GoogleIntegrationPanel(
                    repository: _Connected(), admin: true)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect gym Google account?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
  testWidgets('narrow Coach status has no overflow and shows sync uncertainty', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: GoogleIntegrationPanel(repository: _Uncertain(), coachId: 'coach')))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Outcome uncertain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('changing repositories discards a late previous account status', (tester) async {
    final old = _Pending();
    Widget screen(GoogleIntegrationRepository r) => MaterialApp(home: Scaffold(body: GoogleIntegrationPanel(repository: r, coachId: 'coach')));
    await tester.pumpWidget(screen(old)); await tester.pump();
    await tester.pumpWidget(screen(const DisconnectedGoogleIntegrationRepository())); await tester.pumpAndSettle();
    old.pending.complete(const GoogleIntegrationStatus(connectionStatus: 'connected', calendarStatus: 'ready'));
    await tester.pumpAndSettle();
    expect(find.text('Gym connection: Not connected'), findsOneWidget);
    expect(find.text('Gym connection: Connected'), findsNothing);
  });
}

class _Connected extends DisconnectedGoogleIntegrationRepository {
  @override
  Future<GoogleIntegrationStatus> load({String? coachId}) async =>
      const GoogleIntegrationStatus(
          connectionStatus: 'connected', senderEmail: 'gym@example.com');
}
class _Automatic extends DisconnectedGoogleIntegrationRepository {
  @override Future<GoogleIntegrationStatus> load({String? coachId}) async => const GoogleIntegrationStatus(connectionStatus: 'connected', calendarStatus: 'ready', automationEnabled: true, automationStatus: 'email_needs_review', emailSyncStatus: 'uncertain');
}
class _Uncertain extends DisconnectedGoogleIntegrationRepository {
 @override Future<GoogleIntegrationStatus> load({String? coachId}) async => const GoogleIntegrationStatus(connectionStatus: 'connected', calendarStatus: 'ready', syncStatus: 'uncertain');
}
class _Pending extends DisconnectedGoogleIntegrationRepository {
 final pending = Completer<GoogleIntegrationStatus>();
 @override Future<GoogleIntegrationStatus> load({String? coachId}) => pending.future;
}
