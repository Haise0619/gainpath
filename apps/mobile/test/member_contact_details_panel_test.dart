import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_contact_details_panel.dart';

class _Repository implements MemberContactDetailsRepository {
  String value = 'Existing contact';
  bool fail = false;
  @override
  Future<MemberContactDetails> load() async =>
      MemberContactDetails(value: value, editBaseline: Object());
  @override
  Future<MemberContactDetails> save(
      MemberContactDetails original, String next) async {
    if (fail) {
      throw const MemberContactDetailsException('Changed elsewhere. Reload.',
          reloadRequired: true);
    }
    value = next.trim();
    return load();
  }
}

class _NamedRepository extends _Repository
    implements MemberDisplayNameRepository {
  String name = 'Existing Member';
  int nameWrites = 0;
  @override
  Future<MemberContactDetails> load() async => MemberContactDetails(
      value: value, displayName: name, editBaseline: Object());
  @override
  Future<MemberContactDetails> saveDisplayName(
      MemberContactDetails original, String next) async {
    if (this.fail) {
      throw const MemberContactDetailsException('Changed elsewhere. Reload.',
          reloadRequired: true);
    }
    name = next.trim();
    nameWrites++;
    return load();
  }
}

class _AuthRepository extends Fake
    implements AuthRepository, AuthSessionLifecycle {
  _AuthRepository(this.account);
  final _NamedRepository account;
  int restores = 0;
  @override
  Stream<AuthSession?> get sessionChanges => const Stream.empty();
  @override
  Future<AuthSession?> restoreSession() async {
    restores++;
    return AuthSession(
        userId: 'm',
        organizationId: 'o',
        email: 'member@example.test',
        role: AppRole.member,
        displayName: account.name);
  }
}

void main() {
  testWidgets(
      'route back protects unsaved contact and dirty callback clears after save',
      (tester) async {
    final repo = _Repository();
    final dirty = <bool>[];
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    child: const Text('Open contact'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Contact')),
                                body: MemberContactDetailsPanel(
                                    repository: repo,
                                    onDirtyChanged: dirty.add)))))))));
    await tester.tap(find.text('Open contact'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Changed contact');
    await tester.pump();
    expect(dirty.last, true);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save contact details'));
    await tester.pumpAndSettle();
    expect(dirty.last, false);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open contact'), findsOneWidget);
  });
  testWidgets(
      'confirmed name save returns to existing Home with refreshed authoritative session',
      (tester) async {
    final repo = _NamedRepository();
    final authRepo = _AuthRepository(repo);
    final auth = AuthBloc(repository: authRepo);
    addTearDown(auth.close);
    final home = Builder(builder: (context) {
      return Scaffold(
          body: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        return Column(children: [
          Text('Home ${state.session?.displayName ?? 'Loading'}'),
          TextButton(
              onPressed: () {
                final settings = Scaffold(
                    body: SingleChildScrollView(
                        child: MemberContactDetailsPanel(
                            session: auth.state.session, repository: repo)));
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => settings));
              },
              child: const Text('Open settings')),
        ]);
      }));
    });
    await tester.pumpWidget(
        BlocProvider.value(value: auth, child: MaterialApp(home: home)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('member-display-name')), 'Confirmed Member');
    await tester.tap(find.text('Save display name'));
    await tester.pumpAndSettle();
    expect(find.text('Home Confirmed Member'), findsOneWidget);
    expect(find.text('Save display name'), findsNothing);
    expect(authRepo.restores, 2);
    expect(auth.state.session!.userId, 'm');
    expect(auth.state.session!.role, AppRole.member);
    expect(repo.value, 'Existing contact');
  });
  testWidgets(
      'display name preserves contact edits and notifies only after confirmed save',
      (tester) async {
    final repo = _NamedRepository();
    String? confirmed;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MemberContactDetailsPanel(
                    repository: repo,
                    onDisplayNameSaved: (name) => confirmed = name)))));
    await tester.pumpAndSettle();
    expect(find.text('Existing Member'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('member-contact-details')),
        'Unsaved contact');
    await tester.enterText(
        find.byKey(const ValueKey('member-display-name')), '  New Member  ');
    await tester.ensureVisible(find.text('Save display name'));
    await tester.tap(find.text('Save display name'));
    await tester.pumpAndSettle();
    expect(repo.nameWrites, 0);
    expect(repo.value, 'Existing contact');
    expect(confirmed, isNull);
    await tester.ensureVisible(find.text('Save contact details'));
    await tester.tap(find.text('Save contact details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save display name'));
    await tester.tap(find.text('Save display name'));
    await tester.pumpAndSettle();
    expect(repo.name, 'New Member');
    expect(confirmed, 'New Member');
    expect(find.text('Unsaved contact'), findsOneWidget);
    expect(repo.value, 'Unsaved contact');
  });
  testWidgets(
      'empty display name never writes and stale name save requires reload',
      (tester) async {
    final repo = _NamedRepository();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: MemberContactDetailsPanel(repository: repo)))));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('member-display-name')), '   ');
    await tester.ensureVisible(find.text('Save display name'));
    await tester.tap(find.text('Save display name'));
    await tester.pumpAndSettle();
    expect(repo.nameWrites, 0);
    repo.fail = true;
    await tester.enterText(
        find.byKey(const ValueKey('member-display-name')), 'Changed');
    await tester.tap(find.text('Save display name'));
    await tester.pumpAndSettle();
    expect(find.text('Changed elsewhere. Reload.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save display name'))
            .onPressed,
        isNull);
  });
  testWidgets('saved contact loads, updates, reopens and clears',
      (tester) async {
    final repo = _Repository();
    Future<void> mount() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MemberContactDetailsPanel(
                  key: UniqueKey(), repository: repo))));
      await tester.pumpAndSettle();
    }

    await mount();
    expect(find.text('Existing contact'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '+60 12 345 6789');
    await tester.tap(find.text('Save contact details'));
    await tester.pumpAndSettle();
    expect(repo.value, '+60 12 345 6789');
    expect(find.text('Contact details saved.'), findsOneWidget);
    await mount();
    expect(find.text('+60 12 345 6789'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear contact details'));
    await tester.tap(find.text('Save contact details'));
    await tester.pumpAndSettle();
    expect(repo.value, isEmpty);
  });
  testWidgets(
      'stale save retains input and blocks writes until explicit reload',
      (tester) async {
    final repo = _Repository()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MemberContactDetailsPanel(repository: repo))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved contact');
    await tester.tap(find.text('Save contact details'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved contact'), findsOneWidget);
    expect(find.text('Changed elsewhere. Reload.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save contact details'))
            .onPressed,
        isNull);
    repo.fail = false;
    await tester.tap(find.text('Reload contact details'));
    await tester.pumpAndSettle();
    expect(find.text('Existing contact'), findsOneWidget);
  });
  testWidgets('Mock contact editor works without Firebase', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MemberContactDetailsPanel())));
    await tester.enterText(
        find.byKey(const ValueKey('member-contact-details')), 'Mock contact');
    await tester.tap(find.text('Save contact details'));
    await tester.pumpAndSettle();
    expect(find.text('Saved in Mock Mode.'), findsOneWidget);
  });
}
