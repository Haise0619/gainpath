import 'package:gainpath_mobile/features/workout/presentation/member/equipment_scanner_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/app/mobile_app.dart';
import 'package:gainpath_mobile/features/analytics/data/local_member_progress_repository.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/equipment_browse_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'support/fitness_profile_fake.dart';

GymEquipment equipment(String name, {bool active = true}) => GymEquipment(
    id: name,
    name: name,
    category: 'Legs',
    muscleGroup: 'Legs',
    description: 'Catalog description',
    imageUrl: '',
    howToUse: ['Read the equipment instructions'],
    safetyTips: ['Use appropriate supervision'],
    isActive: active,
    revision: 1);

class _Reader implements EquipmentReader {
  List<GymEquipment> records = [];
  Completer<EquipmentPage>? pending;
  bool fail = false;
  @override
  Future<EquipmentPage> loadEquipment({String? afterId}) async {
    if (fail) throw StateError('Private transport detail');
    if (pending != null) return pending!.future;
    return afterId == null
        ? EquipmentPage(records.take(2),
            nextCursor: records.length > 2 ? records[1].id : null)
        : EquipmentPage(records.skip(2));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'Firebase Member Home Equipment entry opens scoped browsing without recording activity',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = InMemoryAuthRepository(), profiles = FakeProfileGateway();
    final session = await auth.signIn(
        email: 'member@example.test', password: 'password123');
    await profiles.repository(session.scope).save(sampleProfile());
    final reader = _Reader()..records = [equipment('Published equipment')];
    final store = InMemoryWorkoutSessionStore(scope: session.scope),
        sync = MemoryRealWorkoutSyncStore(scope: session.scope);
    final before = (await sync.read()).toJson();
    await tester.pumpWidget(GainPathMobileApp.injected(
        authRepository: auth,
        profileRepositoryFactory: profiles.repository,
        routineLoaderFactory: (_) async => null,
        equipmentReaderFactory: (scope, active) {
          expect(scope, session.scope);
          expect(active(), session.scope);
          return reader;
        },
        progressRepositoryFactory: (scope, active) async =>
            StoredLocalMemberProgressRepository(
                scope: scope,
                workoutStore: store,
                syncStore: sync,
                activeScope: active)));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipment'));
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentScannerScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Browse all equipment'));
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentBrowseScreen), findsOneWidget);
    expect(find.text('Published equipment'), findsOneWidget);
    expect(await store.read(), isEmpty);
    expect((await sync.read()).toJson(), before);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
      'Member browses active pages, reads real details and refreshes after deactivation without mock playback',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reader = _Reader()
      ..records = [
        equipment('Hidden', active: false),
        equipment('Published equipment'),
        equipment('More equipment')
      ];
    await tester
        .pumpWidget(MaterialApp(home: EquipmentBrowseScreen(reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('Hidden'), findsNothing);
    await tester.tap(find.text('Published equipment'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog description'), findsOneWidget);
    expect(find.text('EQUIPMENT IMAGE'), findsOneWidget);
    expect(find.text('TUTORIAL VIDEO'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more equipment'));
    await tester.pumpAndSettle();
    expect(find.text('More equipment'), findsOneWidget);
    reader.records = [equipment('Published equipment', active: false)];
    await tester.tap(find.byTooltip('Refresh equipment'));
    await tester.pumpAndSettle();
    expect(find.text('No active equipment is available.'), findsOneWidget);
  });
  testWidgets(
      'new account reader replaces delayed responses; errors are sanitized and retryable',
      (tester) async {
    final old = _Reader()..pending = Completer<EquipmentPage>();
    final current = _Reader()..records = [equipment('New account equipment')];
    Widget app(_Reader reader) =>
        MaterialApp(home: EquipmentBrowseScreen(reader: reader));
    await tester.pumpWidget(app(old));
    await tester.pump();
    await tester.pumpWidget(app(current));
    await tester.pumpAndSettle();
    old.pending!.complete(EquipmentPage([equipment('Old account equipment')]));
    await tester.pumpAndSettle();
    expect(find.text('New account equipment'), findsOneWidget);
    expect(find.text('Old account equipment'), findsNothing);
    current.fail = true;
    await tester.tap(find.byTooltip('Refresh equipment'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load equipment'), findsOneWidget);
    expect(find.textContaining('Private transport detail'), findsNothing);
    current.fail = false;
    current.records = [];
    await tester.tap(find.text('Retry equipment'));
    await tester.pumpAndSettle();
    expect(find.text('No active equipment is available.'), findsOneWidget);
  });
}
