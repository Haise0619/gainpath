import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/identity.dart';
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

void main() {
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
    await tester.enterText(find.byType(TextField), 'Mock contact');
    await tester.tap(find.text('Save contact details'));
    await tester.pumpAndSettle();
    expect(find.text('Saved in Mock Mode.'), findsOneWidget);
  });
}
