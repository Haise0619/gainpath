import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_profile_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

class _FakeAuthBloc extends Fake implements AuthBloc {
  _FakeAuthBloc(this.state);
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState state;

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  Future<void> close() async {
    await _controller.close();
  }
}

void main() {
  setUpAll(loadDemoRenderFonts);

  const testSession = AuthSession(
    userId: 'member1',
    organizationId: 'gym1',
    email: 'alex.zheng@example.com',
    displayName: 'Alex Zheng',
    role: AppRole.member,
  );

  final testProfile = FitnessProfile(
    gender: ProfileGender.male,
    age: 28,
    heightCm: 178,
    weightKg: 74,
    experience: TrainingExperience.intermediate,
    activity: ActivityLevel.moderatelyActive,
    goals: {FitnessGoal.buildMuscle},
  );

  Future<void> saveScreenshot(
      Key key, WidgetTester tester, String brainArtifactFilename) async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
          'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314/$brainArtifactFilename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget wrapWithTheme({
    required Widget child,
    required Key key,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMemberTypographyTheme(),
      builder: (context, c) => RepaintBoundary(
        key: key,
        child: c!,
      ),
      home: child,
    );
  }

  testWidgets('Render Redesigned MemberProfileScreen at 393dp width',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(393, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final authBloc = _FakeAuthBloc(
      const AuthState(
        status: AuthStatus.signedIn,
        role: AppRole.member,
        session: testSession,
      ),
    );
    addTearDown(authBloc.close);

    final key = GlobalKey();
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: wrapWithTheme(
          key: key,
          child: MemberProfileScreen(
            liveSession: testSession,
            liveProfile: testProfile,
            onOpenProgress: () {},
            onOpenAchievements: () {},
            supportBuilder: (_) => const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'member_profile_redesign_393.png');
  });

  testWidgets('Render Redesigned MemberProfileScreen at 320dp width',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final authBloc = _FakeAuthBloc(
      const AuthState(
        status: AuthStatus.signedIn,
        role: AppRole.member,
        session: testSession,
      ),
    );
    addTearDown(authBloc.close);

    final key = GlobalKey();
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: wrapWithTheme(
          key: key,
          child: MemberProfileScreen(
            liveSession: testSession,
            liveProfile: testProfile,
            onOpenProgress: () {},
            onOpenAchievements: () {},
            supportBuilder: (_) => const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await saveScreenshot(key, tester, 'member_profile_redesign_320_2x.png');
  });
}
