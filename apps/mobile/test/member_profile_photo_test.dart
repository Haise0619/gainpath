import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_profile_photo.dart';

final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==');

class _Picker implements AccountPhotoPicker {
  bool invalid = false, cancel = false;
  @override
  Future<AccountPhoto?> pick() async {
    if (invalid) throw const FormatException('Choose a valid image.');
    return cancel ? null : AccountPhoto(png);
  }
}

class _Repository implements MemberPhotoRepository {
  MemberPhoto current = MemberPhoto(path: '', editBaseline: Object());
  Uint8List? bytes;
  bool fail = false, unreadable = false;
  @override
  Future<MemberPhoto> load() async => current;
  @override
  Future<Uint8List?> readPhoto(MemberPhoto original) async {
    if(unreadable)throw const AccountPhotoUnavailable();
    return bytes;
  }
  @override
  Future<MemberPhoto> save(MemberPhoto original,
      {AccountPhoto? photo, bool remove = false}) async {
    if (fail) {
      throw const MemberPhotoException('Changed elsewhere. Reload.',
          reloadRequired: true);
    }
    if (original != current) throw const MemberPhotoException('Stale');
    bytes = remove ? null : photo!.bytes;
    current =
        MemberPhoto(path: remove ? '' : 'owned-photo', editBaseline: Object());
    return current;
  }
}

void main() {
  testWidgets(
      'existing camera opens editor; save, reopen and clear update avatar',
      (tester) async {
    final repo = _Repository(), picker = _Picker();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MemberProfilePhoto(repository: repo, picker: picker))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save picture'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(repo.current.path, 'owned-photo');
    await tester.tap(find.byTooltip('Edit profile picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save picture'));
    await tester.pumpAndSettle();
    expect(repo.current.path, isEmpty);
    expect(find.byType(Image), findsNothing);
  });
  testWidgets('unreadable saved object can be cleared from its reference',(tester)async{
    final repo=_Repository()..current=MemberPhoto(path:'missing-owned-photo',editBaseline:Object())..unreadable=true;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:MemberProfilePhoto(repository:repo,picker:_Picker()))));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile picture'));await tester.pumpAndSettle();
    await tester.tap(find.text('Remove picture'));await tester.pumpAndSettle();
    await tester.tap(find.text('Save picture'));await tester.pumpAndSettle();
    expect(repo.current.path,isEmpty);
  });
  testWidgets('reopening after a concurrent edit loads a fresh baseline',(tester)async{
    final repo=_Repository();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:MemberProfilePhoto(repository:repo,picker:_Picker()))));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile picture'));await tester.pumpAndSettle();
    repo.current=MemberPhoto(path:'',editBaseline:Object());
    await tester.tap(find.text('Choose image'));await tester.pumpAndSettle();await tester.tap(find.text('Save picture'));await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile picture'));await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));await tester.pumpAndSettle();await tester.tap(find.text('Save picture'));await tester.pumpAndSettle();
    expect(repo.current.path,'owned-photo');
  });
  testWidgets(
      'invalid selection shows error; uncertain save requires reopening',
      (tester) async {
    final repo = _Repository(), picker = _Picker()..invalid = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MemberProfilePhoto(repository: repo, picker: picker))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile picture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a valid image.'), findsOneWidget);
    picker.invalid = false;
    repo.fail = true;
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save picture'));
    await tester.pumpAndSettle();
    expect(find.text('Changed elsewhere. Reload.'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save picture'))
            .onPressed,
        isNull);
    expect(repo.current.path, isEmpty);
  });
  testWidgets('Mock camera supports selection and clear without Firebase',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: MemberProfilePhoto(picker: _Picker()))));
    await tester.tap(find.byTooltip('Edit profile picture'));
    await tester.pumpAndSettle();
    expect(
        find.text('Mock Mode: photo stays in this session.'), findsOneWidget);
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save picture'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });
}
