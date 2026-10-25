import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/src/google_integration_panel.dart';

void main() {
  testWidgets(
      'shared panel reports automatic delivery and uncertain email without a resend action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GoogleIntegrationPanel(
                    actions: _actions(
                        load: ({coachId}) async =>
                            const GoogleIntegrationPanelStatus(
                                connectionStatus: 'connected',
                                calendarStatus: 'ready',
                                automationEnabled: true,
                                automationStatus: 'email_needs_review',
                                emailSyncStatus: 'uncertain')),
                    admin: true,
                    coachId: 'coach',
                    loadCoaches: () async => {'coach': 'Coach'})))));
    await tester.pumpAndSettle();
    expect(
        find.text('Automatic delivery: Enabled for approved test recipients'),
        findsOneWidget);
    expect(find.textContaining('Automatic delivery needs Admin review'),
        findsOneWidget);
    expect(find.textContaining('Email: Outcome uncertain'), findsOneWidget);
    expect(find.text('Retry email'), findsNothing);
  });
  testWidgets(
      'Coach sees gym-managed status without connect or delivery actions',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GoogleIntegrationPanel(
                actions: _actions(), coachId: 'coach'))));
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
                    actions: _actions(
                        load: ({coachId}) async =>
                            const GoogleIntegrationPanelStatus(
                                connectionStatus: 'connected',
                                senderEmail: 'gym@example.com')),
                    admin: true)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect gym Google account?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
  testWidgets('narrow Coach status has no overflow and shows sync uncertainty',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: GoogleIntegrationPanel(
                    actions: _actions(
                        load: ({coachId}) async =>
                            const GoogleIntegrationPanelStatus(
                                connectionStatus: 'connected',
                                calendarStatus: 'ready',
                                syncStatus: 'uncertain')),
                    coachId: 'coach')))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Outcome uncertain'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('changing repositories discards a late previous account status',
      (tester) async {
    final pending = Completer<GoogleIntegrationPanelStatus>();
    final old = _actions(load: ({coachId}) => pending.future);
    Widget screen(GoogleIntegrationPanelActions r) => MaterialApp(
        home: Scaffold(
            body: GoogleIntegrationPanel(actions: r, coachId: 'coach')));
    await tester.pumpWidget(screen(old));
    await tester.pump();
    await tester.pumpWidget(screen(_actions()));
    await tester.pumpAndSettle();
    pending.complete(const GoogleIntegrationPanelStatus(
        connectionStatus: 'connected', calendarStatus: 'ready'));
    await tester.pumpAndSettle();
    expect(find.text('Gym connection: Not connected'), findsOneWidget);
    expect(find.text('Gym connection: Connected'), findsNothing);
  });
  testWidgets(
      'rebuilding callbacks for the same account preserves its pending status',
      (tester) async {
    final account = Object();
    final pending = Completer<GoogleIntegrationPanelStatus>();
    var loads = 0;
    Widget screen() => MaterialApp(
            home: Scaffold(
                body: GoogleIntegrationPanel(
          actions: _actions(
              identity: account,
              load: ({coachId}) {
                loads++;
                return pending.future;
              }),
          coachId: 'coach',
        )));
    await tester.pumpWidget(screen());
    await tester.pumpWidget(screen());
    pending.complete(
        const GoogleIntegrationPanelStatus(connectionStatus: 'connected'));
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.text('Gym connection: Connected'), findsOneWidget);
  });
}

GoogleIntegrationPanelActions _actions({
  Object? identity,
  Future<GoogleIntegrationPanelStatus> Function({String? coachId})? load,
}) =>
    GoogleIntegrationPanelActions(
      identity: identity,
      load: load ??
          ({String? coachId}) async => const GoogleIntegrationPanelStatus(),
      beginConnect: () async => throw StateError('Unavailable'),
      disconnect: () async {},
      acknowledgeRevocation: () async {},
      createCoachCalendar: (_) async {},
      syncBooking: (_, {required bool email}) async =>
          throw StateError('Unavailable'),
    );
