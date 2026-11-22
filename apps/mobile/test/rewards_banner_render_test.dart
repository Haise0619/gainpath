import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_check_in_test.dart' show snapshotJson;

class _LocalAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    for (final path in [
      key,
      'apps/mobile/$key',
      'C:/Users/Ngzhe/StudioProjects/gainpath/apps/mobile/$key',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        return ByteData.sublistView(bytes);
      }
    }
    return rootBundle.load(key);
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('render rewards page first section with compressed trophy banner',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final scope = SessionScope(userId: 'member-1', organizationId: 'gym-1');
    final rawJson = snapshotJson(scope, claimed: false);
    rawJson['balance'] = 2450;
    final snapshot = AppCheckInSnapshot.fromJson(rawJson, scope);
    final state = AppCheckInState(
      status: AppCheckInStatus.ready,
      snapshot: snapshot,
    );

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _LocalAssetBundle(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFAF8FF),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6D28D9),
              surface: Colors.white,
            ),
          ),
          builder: (context, child) => RepaintBoundary(
            key: repaintKey,
            child: child!,
          ),
          home: Scaffold(
            body: AppCheckInDashboard(
              state: state,
              onClaim: () async {},
              onRefresh: () async {},
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 2,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    label: 'Workout'),
                NavigationDestination(
                    icon: Icon(Icons.emoji_events), label: 'Rewards'),
                NavigationDestination(
                    icon: Icon(Icons.people_outline), label: 'Coaches'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Points section
    expect(find.text('YOUR POINTS'), findsOneWidget);
    expect(find.text('2450'), findsOneWidget);

    final outDir = Directory(
        r'C:\Users\Ngzhe\.gemini\antigravity\brain\2e9bce9b-03ec-4533-aa97-83c6a91f9314');

    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/rewards_page_new_banner_full.png');
      await file.writeAsBytes(bytes);
      image.dispose();
    });
  });
}
