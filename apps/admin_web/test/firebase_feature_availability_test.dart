import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:google_fonts/google_fonts.dart';

class _EmptyPhotoAccount extends Fake implements AdminAccountContactRepository {
  @override
  Future<Uint8List?> loadCurrentPhoto() async => null;
}

class _Members implements AdminMemberDirectoryRepository {
  @override
  Future<AdminMemberPage> loadPage(
          {String query = '', String status = 'All', String? afterId}) async =>
      AdminMemberPage(const [
        AdminMemberRecord(
            id: 'member',
            name: 'Connected Member',
            email: 'member@example.test',
            status: 'active')
      ]);
}

const _session = AuthSession(
  userId: 'live-admin',
  organizationId: 'connected-org',
  branchIds: ['connected-branch'],
  displayName: 'Connected Administrator',
  email: 'connected@example.test',
  role: AppRole.admin,
);

class _Catalog implements TutorialRepository {
  int loads = 0;
  @override
  final tutorials = [
    TutorialVideo(
        id: 'isolated-exercise',
        title: 'Isolated catalog row',
        category: 'Lower body',
        status: TutorialStatus.active)
  ];
  @override
  bool get requiresCatalogSelection => true;
  @override
  Future<List<TutorialVideo>> load() async {
    loads++;
    return tutorials;
  }

  @override
  Future<TutorialVideo> save(TutorialVideo tutorial) async => tutorial;
}

class _Blueprints extends RoutineTemplateRepository {
  int loads = 0;
  @override
  final routineTemplates = [
    RoutineBlueprint(
        id: 'isolated-blueprint',
        name: 'Isolated routine row',
        level: 'Beginner',
        assignedMembers: 0,
        days: [])
  ];
  @override
  Future<List<RoutineBlueprint>> load() async {
    loads++;
    return routineTemplates;
  }
}

class _SignedInAuthRepository implements AuthRepository, AuthSessionLifecycle {
  @override
  Stream<AuthSession?> get sessionChanges => const Stream.empty();
  @override
  Future<AuthSession?> restoreSession() async => _session;
  @override
  Future<AuthSession> signIn({
    AppRole? role,
    required String email,
    required String password,
  }) async =>
      _session;
  @override
  Future<AuthSession> register({
    required AppRole role,
    required String email,
    required String password,
    required String name,
  }) async =>
      _session;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'connected catalog and routine pages use scoped ports without opening unsupported pages',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = _Catalog(), blueprints = _Blueprints();
    final scopes = <SessionScope>[];
    await tester.pumpWidget(GainPathAdminWebApp(
        accountContactFactory: (_, __) => _EmptyPhotoAccount(),
        authRepository: _SignedInAuthRepository(),
        backendConfig: const BackendConfig(BackendMode.firebase),
        tutorialRepositoryFactory: (scope) {
          scopes.add(scope);
          return catalog;
        },
        routineRepositoryFactory: (scope, providedCatalog) {
          scopes.add(scope);
          expect(providedCatalog, same(catalog));
          return blueprints;
        }));
    await tester.pumpAndSettle();
    expect(catalog.loads, 0);
    expect(blueprints.loads, 0);
    await tester.tap(find.text('Content'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise Tutorials').first);
    await tester.pumpAndSettle();
    expect(find.text('Isolated catalog row'), findsOneWidget);
    expect(catalog.loads, 1);
    await tester.tap(find.text('Routine Templates').first);
    await tester.pumpAndSettle();
    expect(find.text('Isolated routine row'), findsOneWidget);
    expect(blueprints.loads, 1);
    expect(scopes, [_session.scope, _session.scope]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Firebase composition does not provide seeded accounts',
      (tester) async {
    await tester.pumpWidget(AppRepositories(
      config: const BackendConfig(BackendMode.firebase),
      session: _session,
      child: MaterialApp(home: Builder(builder: (context) {
        UserAccountRepository? accounts;
        try {
          accounts = context.read<UserAccountRepository>();
        } catch (_) {
          // Absence is the expected live-mode contract.
        }
        return Text(
            accounts == null ? 'accounts unavailable' : accounts.adminName);
      })),
    ));
    expect(find.text('accounts unavailable'), findsOneWidget);
  });

  testWidgets('Firebase dashboard boots with the actual authenticated account',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GainPathAdminWebApp(
      memberDirectoryFactory: (_, __) => _Members(),
      accountContactFactory: (_, __) => _EmptyPhotoAccount(),
      authRepository: _SignedInAuthRepository(),
      backendConfig: const BackendConfig(BackendMode.firebase),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_session.email), findsWidgets);
    expect(find.text(_session.displayName!), findsWidgets);
    expect(find.text('GainPath, Kulim'), findsNothing);
    expect(find.text('Recent activity'), findsNothing);
    await tester.tap(find.text('Members').first);
    await tester.pumpAndSettle();
    expect(find.text('Connected Member'), findsOneWidget);
    expect(find.text('Members unavailable'), findsNothing);
    expect(find.text('Suspend account'), findsNothing);
    for (final feature in ['Refunds', 'Reports']) {
      await tester.tap(find.text(feature).first);
      await tester.pumpAndSettle();
      expect(find.text('$feature unavailable'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Recent activity'), findsNothing);
    }
    await tester.tap(find.text('Governance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reward Catalog').first);
    await tester.pumpAndSettle();
    expect(find.text('Reward Catalog unavailable'), findsOneWidget);
    expect(find.text('Add reward'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
