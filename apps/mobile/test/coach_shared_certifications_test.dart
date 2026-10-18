import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/identity/application/coach_account_gateway.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/certifications_screen.dart';

class CertGateway extends Fake implements CoachAccountGateway {
  CertGateway(this.backend);
  final String backend;
  int uploads = 0, submits = 0;
  bool active = true, failReadback = false;
  final requests = <String>[];
  List<PrivateCoachCertification> records = [
    cert('pending'),
    cert('rejected', reason: 'Upload a legible document'),
    cert('unexpected')
  ];
  static PrivateCoachCertification cert(String status, {String? reason}) =>
      PrivateCoachCertification(
          id: status.padRight(32, 'a'),
          title: 'Credential $status',
          issuer: 'Issuer',
          storagePath: 'private/evidence',
          status: status,
          revision: 1,
          createdAtMillis: 1700000000000,
          updatedAtMillis: 1700000000000,
          reason: reason);
  @override
  SessionScope get scope => SessionScope(userId: 'coach', organizationId: 'o');
  @override
  bool Function() get isCurrent => () => active;
  @override
  void check() {
    if (!active) throw const CoachRepositoryException('unauthenticated');
  }

  @override
  String? get certificationCursor => null;
  @override
  Future<List<PrivateCoachCertification>> loadCertifications(
      {String? afterId}) async {
    if (failReadback && submits > 0) {
      throw const CoachRepositoryException('unavailable');
    }
    return records;
  }

  @override
  Future<String> upload(
      String collection, String id, Uint8List bytes, String contentType) async {
    uploads++;
    return 'private/new';
  }

  @override
  Future<void> submitCertification(String id, String title, String issuer,
      String path, String requestId) async {
    requests.add(requestId);
    submits++;
    records = [cert('pending')];
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final backend in ['Mock', 'Firebase']) {
    testWidgets(
        '$backend supplies the same canonical certification cards and friendly statuses',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: CertificationsScreen(repository: CertGateway(backend))));
      await tester.pumpAndSettle();
      expect(find.byType(CertificationsScreen), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Upload a legible document'), findsOneWidget);
      expect(find.textContaining('1700000000000'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'real file selection uses gateway upload then reload before success',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = CertGateway('neutral')..records = [];
    await tester.pumpWidget(MaterialApp(
        home: CertificationsScreen(
            repository: gateway,
            pickEvidence: () async => CoachCertificationFile(
                Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Certification title'), 'Title');
    await tester.enterText(
        find.widgetWithText(TextField, 'Issuing organization'), 'Issuer');
    await tester.tap(find.text('Upload a certificate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(gateway.uploads, 1);
    expect(gateway.submits, 1);
    expect(find.text('Submitted for Admin review.'), findsOneWidget);
    expect(find.text('Credential pending'), findsOneWidget);
  });
  testWidgets(
      'failed authoritative reload retains upload intent and retries the same command',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = CertGateway('neutral')
      ..records = []
      ..failReadback = true;
    await tester.pumpWidget(MaterialApp(
        home: CertificationsScreen(
            repository: gateway,
            pickEvidence: () async => CoachCertificationFile(
                Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10])))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Certification title'), 'Title');
    await tester.enterText(
        find.widgetWithText(TextField, 'Issuing organization'), 'Issuer');
    await tester.tap(find.text('Upload a certificate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(find.text('Submitted for Admin review.'), findsNothing);
    expect(gateway.uploads, 1);
    gateway.failReadback = false;
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(gateway.uploads, 1);
    expect(gateway.requests.toSet(), hasLength(1));
    expect(find.text('Submitted for Admin review.'), findsOneWidget);
  });
}
