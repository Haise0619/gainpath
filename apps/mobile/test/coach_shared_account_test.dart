import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_data/gainpath_data.dart' show InMemoryAuthRepository;
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_presentation.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/live_coach_profile_views.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'package:gainpath_mobile/infrastructure/firebase/firebase_coach_account_repository.dart';

CoachProfessionalProfile draft({String? path}) => CoachProfessionalProfile(
    id: 'coach',
    fields: CoachProfessionalFields(
        displayName: 'Actual Coach',
        specialty: 'Strength',
        bio: 'Owner draft biography',
        specializationTags: ['Strength'],
        yearsExperience: 4,
        consultationFeeMinor: 12000,
        photoPath: path),
    revision: 2,
    createdAtMillis: 1,
    updatedAtMillis: 2);

class FailingAvatarAccount extends FirebaseCoachAccountRepository {
  int photoLoads = 0;
  FailingAvatarAccount()
      : super(
            scope: SessionScope(userId: 'coach', organizationId: 'o'),
            isCurrent: () => true);
  @override
  void check() {}
  @override
  Future<Uint8List?> loadProfilePhoto(String? path) async {
    photoLoads++;
    throw const FormatException('Invalid image');
  }
  @override
  Future<Map<String, dynamic>> command(String name,
          [Map<String, dynamic> values = const {}]) async =>
      {
        'schemaVersion': 1,
        'approvedCount': 0,
        'certificationVerified': false,
        'certifications': [],
        'nextCursor': null
      };
}

Future<void> snapshot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('../../build/module-8-shared-ui');
      await folder.create(recursive: true);
      await File('${folder.path}/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Mock and Firebase bindings render the same purple account presentation',
      (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: RepositoryProvider<CoachRepository>.value(
            value: InMemoryCoachRepository(),
            child: const MaterialApp(home: CoachAccountScreen()))));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountPresentation), findsOneWidget);
    expect(find.byKey(const Key('coach-professional-header')), findsOneWidget);
    for (final label in [
      'Rating',
      'Sessions',
      'Experience',
      'Preview public profile',
      'Bio & specialties',
      'Certifications',
      'Profile photo',
      'Settings'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    final mockGradient = tester
        .widget<Container>(find.byKey(const Key('coach-professional-header')))
        .decoration as BoxDecoration;
    expect(mockGradient.gradient, AppColors.heroGradient);
    await snapshot(tester, boundaryKey, 'mock-coach-account');
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
            home: LiveCoachAccountView(
                repository: ProfileFake(),
                isCurrent: () => true,
                onSignOut: () {},
                onOpenEditor: (_) {}))));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountPresentation), findsOneWidget);
    for (final label in [
      'Rating',
      'Sessions',
      'Experience',
      'Preview public profile',
      'Bio & specialties',
      'Certifications',
      'Profile photo',
      'Settings'
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('-'), findsWidgets);
    final liveGradient = tester
        .widget<Container>(find.byKey(const Key('coach-professional-header')))
        .decoration as BoxDecoration;
    expect(liveGradient.gradient, mockGradient.gradient);
    await snapshot(tester, boundaryKey, 'firebase-coach-account');
  });
  testWidgets('live profile has a real owner draft preview and editing action',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var edits = 0;
    await tester.pumpWidget(MaterialApp(
        home: LiveCoachAccountView(
            repository: ProfileFake()..profile = draft(),
            isCurrent: () => true,
            onSignOut: () {},
            onOpenEditor: (_) => edits++)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview public profile'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountProfilePreview), findsOneWidget);
    expect(find.byType(CoachProfessionalHeader), findsOneWidget);
    expect(find.text('Owner draft preview — not published'), findsOneWidget);
    expect(find.text('Owner draft biography'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bio & specialties'));
    expect(edits, 1);
  });
  testWidgets(
      'invalid saved avatar remains a placeholder and cannot block owner preview',
      (tester) async {
    final auth = AuthBloc(repository: InMemoryAuthRepository());
    final account = FailingAvatarAccount();
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: LiveCoachAccountView(
                repository: ProfileFake()
                  ..profile = draft(
                      path: 'orgs/o/coachProfilePhotos/coach/${'a' * 32}'),
                accountRepository: account,
                isCurrent: () => true,
                onSignOut: () {}))));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person), findsOneWidget);
    await tester.tap(find.text('Preview public profile'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountProfilePreview), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(account.photoLoads, 1);
    await tester.tap(find.byTooltip('Refresh profile'));
    await tester.pumpAndSettle();
    expect(account.photoLoads, 2);
    expect(find.byIcon(Icons.person), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(auth.close);
  });
}
