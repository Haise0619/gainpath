import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/identity/application/coach_account_gateway.dart';
import 'package:gainpath_mobile/features/identity/application/coach_profile_cubit.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/certifications_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/edit_coach_profile_screen.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'support/coach_account_gateway_fake.dart';

class _FakeCertGateway extends Fake implements CoachAccountGateway {
  final records = [
    PrivateCoachCertification(
      id: 'cert_1'.padRight(32, 'a'),
      title: 'Certified Personal Trainer (CPT)',
      issuer: 'National Academy of Sports Medicine (NASM)',
      storagePath: 'private/evidence_1',
      status: 'approved',
      revision: 1,
      createdAtMillis: 1700000000000,
      updatedAtMillis: 1700000000000,
    ),
    PrivateCoachCertification(
      id: 'cert_2'.padRight(32, 'b'),
      title: 'Certified Strength & Conditioning Specialist',
      issuer: 'NSCA',
      storagePath: 'private/evidence_2',
      status: 'pending',
      revision: 1,
      createdAtMillis: 1700000000000,
      updatedAtMillis: 1700000000000,
    ),
    PrivateCoachCertification(
      id: 'cert_3'.padRight(32, 'c'),
      title: 'CPR / AED Certification',
      issuer: 'American Red Cross',
      storagePath: 'private/evidence_3',
      status: 'rejected',
      revision: 1,
      createdAtMillis: 1700000000000,
      updatedAtMillis: 1700000000000,
      reason: 'Document expired or illegible',
    ),
  ];

  @override
  SessionScope get scope =>
      SessionScope(userId: 'coach_1', organizationId: 'org_1');

  @override
  bool Function() get isCurrent => () => true;

  @override
  void check() {}

  @override
  String? get certificationCursor => null;

  @override
  Future<List<PrivateCoachCertification>> loadCertifications(
          {String? afterId}) async =>
      records;

  @override
  Future<String> upload(String collection, String id, Uint8List bytes,
          String contentType) async =>
      'private/uploaded_doc';

  @override
  Future<void> submitCertification(String id, String title, String issuer,
      String storagePath, String checksum) async {}

  @override
  Future<void> archive(PrivateCoachCertification cert, String reason) async {}
}

CoachProfessionalProfile _fixtureProfile() => CoachProfessionalProfile(
      id: 'coach_1',
      fields: CoachProfessionalFields(
        displayName: 'Master Coach',
        specialty: 'Hypertrophy & Mobility',
        bio: 'Over a decade of coaching high-performance athletes.',
        specializationTags: ['Strength', 'Powerlifting', 'Mobility'],
        yearsExperience: 8,
        consultationFeeMinor: 15000,
      ),
      revision: 1,
      createdAtMillis: 1700000000000,
      updatedAtMillis: 1700000000000,
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('EditCoachProfileScreen render responsiveness', () {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Edit profile renders width $width scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final profileRepo = ProfileFake()..profile = _fixtureProfile();
          final controller = CoachProfileCubit(
            repository: profileRepo,
            isCurrent: () => true,
          );
          await controller.reload();
          final accountGateway = CoachAccountGatewayFake();

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: EditCoachProfileScreen(
                controller: controller,
                accountRepository: accountGateway,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(EditCoachProfileScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Make dirty to trigger sticky save bar
          await tester.enterText(
            find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == 'Display name',
            ),
            'Updated Coach Name',
          );
          await tester.pumpAndSettle();

          expect(find.text('Save profile'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('CertificationsScreen render responsiveness', () {
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'Certifications screen empty renders width $width scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 1600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final gateway = _FakeCertGateway()..records.clear();

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: CertificationsScreen(repository: gateway),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CertificationsScreen), findsOneWidget);
          expect(find.text('Verified Credentials'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('UPLOAD CERTIFICATION'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('UPLOAD CERTIFICATION'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets(
            'Certifications screen populated renders width $width scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final gateway = _FakeCertGateway();

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: CertificationsScreen(repository: gateway),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CertificationsScreen), findsOneWidget);
          expect(find.text('Verified Credentials'), findsOneWidget);
          expect(
              find.text('Certified Personal Trainer (CPT)'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.text('UPLOAD CERTIFICATION'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('UPLOAD CERTIFICATION'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
