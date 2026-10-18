import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_data/gainpath_data.dart' show InMemoryAuthRepository;
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/coach_account_presentation.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/edit_coach_profile_screen.dart';
import 'package:gainpath_mobile/infrastructure/local/mock_coach_module8_repository.dart';
import 'coach_profile_state_test.dart' show ProfileFake;
import 'support/coach_account_gateway_fake.dart';

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
Widget frame(Widget child) => BlocProvider(
    create: (_) => AuthBloc(repository: InMemoryAuthRepository()),
    child: MaterialApp(home: child));
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
      'Both data sources instantiate the same canonical profile at 360px without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final mock = MockCoachModule8Repository(
        legacy: InMemoryCoachRepository(),
        scope: SessionScope(userId: 'coach', organizationId: 'o'),
        isCurrent: () => true);
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: frame(CoachAccountScreen(
            profileRepository: mock, accountRepository: mock))));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountScreen), findsOneWidget);
    expect(find.byType(CoachAccountPresentation), findsOneWidget);
    final gradient = (tester
            .widget<Container>(
                find.byKey(const Key('coach-professional-header')))
            .decoration as BoxDecoration)
        .gradient;
    expect(gradient, AppColors.heroGradient);
    expect(find.byType(CoachProfessionalDetails), findsNothing);
    expect(tester.takeException(), isNull);
    await snapshot(tester, boundary, 'canonical-mock-profile');
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: frame(CoachAccountScreen(
            profileRepository: ProfileFake(),
            accountRepository: CoachAccountGatewayFake()))));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountScreen), findsOneWidget);
    expect(find.byType(CoachAccountPresentation), findsOneWidget);
    expect(find.text('-'), findsWidgets);
    expect(find.byType(CoachProfessionalDetails), findsNothing);
    expect(tester.takeException(), isNull);
    await snapshot(tester, boundary, 'canonical-firebase-profile');
    await tester.scrollUntilVisible(find.text('Settings'), 200);
    expect(find.text('Settings'), findsOneWidget);
  });
  testWidgets(
      'Canonical profile opens real draft preview and canonical editor preserving chip and fee design',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final account = CoachAccountGatewayFake();
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: frame(CoachAccountScreen(
            profileRepository: ProfileFake()..profile = draft(),
            accountRepository: account))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview public profile'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountProfilePreview), findsOneWidget);
    expect(find.text('Owner draft preview — not published'), findsOneWidget);
    expect(find.text('Owner draft biography'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await snapshot(tester, boundary, 'canonical-draft-preview');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bio & specialties'));
    await tester.pumpAndSettle();
    expect(find.byType(EditCoachProfileScreen), findsOneWidget);
    expect(find.byType(Chip), findsWidgets);
    expect(find.byType(ActionChip), findsWidgets);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await snapshot(tester, boundary, 'canonical-professional-editor');
    await tester.scrollUntilVisible(find.text('CONSULTATION FEE'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('CONSULTATION FEE'), findsOneWidget);
  });
  testWidgets(
      'Invalid avatar remains a placeholder and cannot block owner preview',
      (tester) async {
    await tester.pumpWidget(frame(CoachAccountScreen(
        profileRepository: ProfileFake()
          ..profile =
              draft(path: 'orgs/o/coachProfilePhotos/coach/${'a' * 32}'),
        accountRepository: CoachAccountGatewayFake()..failAvatar = true)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person), findsOneWidget);
    await tester.tap(find.text('Preview public profile'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachAccountProfilePreview), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
