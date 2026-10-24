import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/main.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/fitness_profile_gate.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/profile_setup_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_account_recovery_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class _Gateway implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  final changes = StreamController<FirebaseAuthUser?>.broadcast();
  bool verified = true;
  bool pendingDeletion = false;
  @override
  Stream<FirebaseAuthUser?> get userChanges => changes.stream;
  @override
  Future<FirebaseAuthUser?> restoreUser() async => FirebaseAuthUser(
          userId: 'member',
          email: 'member@example.com',
          emailVerified: verified,
          claims: {
            'organizationId': 'org',
            'role': 'member',
            'branchIds': ['main'],
            if (pendingDeletion) 'accountLifecycleState': 'pendingDeletion',
            if (pendingDeletion) 'status': 'pendingDeletion'
          });
  @override
  Future<FirebaseAuthUser> signIn(
          {required String email, required String password}) async =>
      (await restoreUser())!;
  @override
  Future<FirebaseAuthUser> register(
          {required String email,
          required String password,
          required String name}) =>
      signIn(email: email, password: password);
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> signOut() async {}
}

class _MissingProfile implements FitnessProfileRepository {
  _MissingProfile(this.scope);
  @override
  final SessionScope scope;
  @override
  Future<FitnessProfile?> load() async => null;
  @override
  Future<void> save(FitnessProfile profile) async {}
}

class _UnavailableLifecycle extends Fake
    implements MemberAccountLifecycleRepository {
  @override
  Future<MemberAccountLifecycle> load() async =>
      throw const MemberAccountLifecycleException(
          'Recovery status needs a connection.');
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'pending accounts mount only recovery and invalidate old recovery sessions',
      (tester) async {
    final gateway = _Gateway()..pendingDeletion = true;
    final auth = FirebaseAuthRepository(gateway);
    var profileLoads = 0;
    final guards = <bool Function()>[];
    await tester.pumpWidget(GainPathMobileApp.injected(
      authRepository: auth,
      profileRepositoryFactory: (scope) {
        profileLoads++;
        return _MissingProfile(scope);
      },
      accountLifecycleFactory: (session, isCurrent) {
        guards.add(isCurrent);
        return _UnavailableLifecycle();
      },
    ));
    await tester.pumpAndSettle();
    expect(find.byType(MemberAccountRecoveryScreen), findsOneWidget);
    expect(find.byType(FitnessProfileGate), findsNothing);
    expect(profileLoads, 0);
    expect(guards.single(), isTrue);
    await auth.restoreSession();
    await tester.pumpAndSettle();
    expect(guards.length, 2);
    expect(guards.first(), isFalse);
    expect(guards.last(), isTrue);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(guards.last(), isFalse);
    expect(find.byType(MemberAccountRecoveryScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    unawaited(auth.dispose());
    unawaited(gateway.changes.close());
  });
  testWidgets(
      'same-member authoritative refresh replaces private routes and repositories',
      (tester) async {
    final gateway = _Gateway();
    final auth = FirebaseAuthRepository(gateway);
    var creations = 0;
    await tester.pumpWidget(GainPathMobileApp.injected(
      authRepository: auth,
      profileRepositoryFactory: (scope) {
        creations++;
        return _MissingProfile(scope);
      },
    ));
    await tester.pumpAndSettle();
    final previous = tester.state(find.byType(FitnessProfileGate));
    final repository = tester
        .widget<FitnessProfileGate>(find.byType(FitnessProfileGate))
        .repository;
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Private draft')))));
    await tester.pumpAndSettle();
    expect(find.text('Private draft'), findsOneWidget);
    await auth.restoreSession();
    await tester.pumpAndSettle();
    expect(previous.mounted, isFalse);
    expect(creations, 2);
    expect(
        identical(
            repository,
            tester
                .widget<FitnessProfileGate>(find.byType(FitnessProfileGate))
                .repository),
        isFalse);
    expect(find.text('Private draft'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    unawaited(auth.dispose());
    unawaited(gateway.changes.close());
  });

  testWidgets(
      'verification button waits for actual Auth reload and keeps unverified feedback',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = _Gateway()..verified = false;
    final auth = FirebaseAuthRepository(gateway);
    await tester.pumpWidget(GainPathMobileApp.injected(
      authRepository: auth,
      profileRepositoryFactory: _MissingProfile.new,
    ));
    // Verification's pulse intentionally remains animated.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(
        find.textContaining('Your email is not verified yet.'), findsOneWidget);
    expect(find.byType(ProfileSetupScreen), findsNothing);
    gateway.verified = true;
    await tester.tap(find.text("I've verified my email"));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    unawaited(auth.dispose());
    unawaited(gateway.changes.close());
  });
}
