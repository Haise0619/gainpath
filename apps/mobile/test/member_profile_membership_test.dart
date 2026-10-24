import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_profile_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'membership_screens_test.dart' show entitlement;
import 'support/fitness_profile_fake.dart' show sampleProfile;

class _Membership implements MembershipCommerceRepository {
  @override
  bool sandbox = false;
  @override
  bool current = true;
  int reads = 0;
  bool fail = false;
  Future<Map<String, dynamic>>? pending;
  Map<String, dynamic> overview = {'entitlement': entitlement()};
  @override
  Future<Map<String, dynamic>> load() async {
    reads++;
    if (fail) throw StateError('Offline');
    return pending ?? overview;
  }

  @override
  Future<Map<String, dynamic>> quote(String planId, String promoCode) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> checkout(String a, String b, String c,
          {required bool renewal, String? quoteId}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> payment(String id) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> refund(String a, String b, String c) =>
      throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, _Membership? repository,
    {WidgetBuilder? membershipBuilder,
    bool live = true,
    double scale = 1,
    Brightness brightness = Brightness.light}) async {
  final auth = AuthBloc(repository: InMemoryAuthRepository());
  addTearDown(auth.close);
  await tester.pumpWidget(RepositoryProvider<MemberProfileRepository>(
    create: (_) => InMemoryMemberProfileRepository(),
    child: BlocProvider.value(
      value: auth,
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.build()
            : ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: child!),
        home: MemberProfileScreen(
          liveSession: live
              ? const AuthSession(
                  email: 'long-member-email-for-profile-layout@example.test',
                  displayName: 'Member with a longer profile name',
                  role: AppRole.member)
              : null,
          liveProfile: live ? sampleProfile() : null,
          membershipRepository: repository,
          membershipBuilder: membershipBuilder,
        ),
      ),
    ),
  ));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final tier in ['free', 'basic', 'premium']) {
    testWidgets('profile displays verified $tier membership and term',
        (tester) async {
      final repo = _Membership()
        ..overview = {
          'entitlement': entitlement(
              tier: tier, paidStatus: tier == 'free' ? 'none' : 'active')
        };
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      final label = '${tier[0].toUpperCase()}${tier.substring(1)}';
      expect(find.text('$label member'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Membership'), 300);
      expect(
          find.textContaining(
              tier == 'free' ? 'Free · No expiry' : '$label · Active until'),
          findsOneWidget);
      expect(repo.reads, 1);
      expect(find.text('- member'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expired paid period displays effective Free and previous tier',
      (tester) async {
    final repo = _Membership()
      ..overview = {'entitlement': entitlement(paidStatus: 'expired')};
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Free member'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Membership'), 300);
    expect(
        find.textContaining('Free · Previous Premium expired'), findsOneWidget);
  });

  testWidgets('cached paid data is explicitly last verified, never active',
      (tester) async {
    final repo = _Membership()
      ..overview = {
        'cached': true,
        'entitlement': entitlement(tier: 'premium', paidStatus: 'active')
      };
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Last verified · Premium'), findsOneWidget);
    expect(find.text('Premium member'), findsNothing);
    await tester.scrollUntilVisible(find.text('Membership'), 300);
    expect(
        find.textContaining('Offline · Last verified Premium'), findsOneWidget);
    expect(find.textContaining('Active until'), findsNothing);
  });

  testWidgets('loading, failure and retry never invent a Free membership',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final repo = _Membership()..pending = pending.future;
    await _pump(tester, repo);
    expect(find.text('Checking membership…'), findsOneWidget);
    pending.completeError(StateError('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Membership unavailable'), findsOneWidget);
    expect(find.text('Free member'), findsNothing);
    repo.pending = null;
    await tester.tap(find.byTooltip('Refresh membership'));
    await tester.pumpAndSettle();
    expect(find.text('Free member'), findsOneWidget);
    expect(repo.reads, 2);
  });

  testWidgets('missing entitlement stays unavailable', (tester) async {
    final repo = _Membership()..overview = {};
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Membership unavailable'), findsOneWidget);
    expect(find.text('Free member'), findsNothing);
  });

  testWidgets('returning from membership refreshes the profile tier',
      (tester) async {
    final repo = _Membership();
    await _pump(tester, repo,
        membershipBuilder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Plan details')),
            body: const SizedBox()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Membership'), 300);
    await tester.tap(find.text('Membership'));
    await tester.pumpAndSettle();
    repo.overview = {
      'entitlement': entitlement(tier: 'basic', paidStatus: 'active')
    };
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Basic member'), -300);
    expect(find.text('Basic member'), findsOneWidget);
    expect(repo.reads, 2);
  });

  testWidgets('late response after session invalidation cannot display tier',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final repo = _Membership()..pending = pending.future;
    await _pump(tester, repo);
    repo.current = false;
    pending.complete(
        {'entitlement': entitlement(tier: 'premium', paidStatus: 'active')});
    await tester.pumpAndSettle();
    expect(find.text('Premium member'), findsNothing);
    expect(find.text('Membership unavailable'), findsOneWidget);
  });

  testWidgets('removing repository clears previously displayed membership',
      (tester) async {
    final repo = _Membership()
      ..overview = {
        'entitlement': entitlement(tier: 'premium', paidStatus: 'active')
      };
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Premium member'), findsOneWidget);
    await _pump(tester, null);
    await tester.pumpAndSettle();
    expect(find.text('Premium member'), findsNothing);
    expect(find.text('Membership unavailable'), findsOneWidget);
  });

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(768, 1024)
  ]) {
    for (final scale in [1.0, 2.0, 3.2]) {
      testWidgets('profile fits $size at text scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _pump(tester, _Membership(), scale: scale);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Sign out'), 300);
        await tester.pumpAndSettle();
        expect(find.text('Sign out'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
