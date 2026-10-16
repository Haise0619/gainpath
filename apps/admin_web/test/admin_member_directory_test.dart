// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/members_screen.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_member_directory_repository.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
  @override
  bool get emailVerified => true;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _Db extends Fake implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{
    'users/admin': {'organizationId': 'o'},
    'orgs/o/members/admin': {
      'organizationId': 'o',
      'role': 'admin',
      'status': 'active'
    },
  };
  int listReads = 0;
  void Function()? afterList;
  void Function(String)? afterGet;
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _Ref(this, path);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Query(this, path);
  void member(String id, {String? name, String status = 'active'}) {
    records['orgs/o/members/$id'] = {
      'organizationId': 'o',
      'role': 'member',
      'displayName': name ?? 'Member $id',
      'email': '$id@example.test',
      'status': status
    };
  }
}

class _Ref extends Fake implements DocumentReference<Map<String, dynamic>> {
  _Ref(this.db, this.path);
  final _Db db;
  @override
  final String path;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    expect(options?.source, Source.server);
    final value = db.records[path];
    final result =
        _Doc(path.split('/').last, value == null ? null : Map.of(value));
    db.afterGet?.call(path);
    return result;
  }
}

class _Doc extends Fake implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic> data() => value!;
  @override
  bool get exists => value != null;
}

class _Page extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Page(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _Query extends Fake implements CollectionReference<Map<String, dynamic>> {
  _Query(this.db, this.path, {this.after, this.cap = 0});
  final _Db db;
  @override
  final String path;
  final String? after;
  final int cap;
  @override
  Query<Map<String, dynamic>> where(Object field,
      {Object? isEqualTo,
      Object? isNotEqualTo,
      Object? isLessThan,
      Object? isLessThanOrEqualTo,
      Object? isGreaterThan,
      Object? isGreaterThanOrEqualTo,
      Object? arrayContains,
      Iterable<Object?>? arrayContainsAny,
      Iterable<Object?>? whereIn,
      Iterable<Object?>? whereNotIn,
      bool? isNull}) {
    expect(field, 'role');
    expect(isEqualTo, 'member');
    return this;
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    expect(field, FieldPath.documentId);
    return this;
  }

  @override
  Query<Map<String, dynamic>> startAfter(Iterable<Object?> values) {
    return _Query(db, path, after: values.single as String, cap: cap);
  }

  @override
  Query<Map<String, dynamic>> limit(int value) {
    expect(value, 101);
    return _Query(db, path, after: after, cap: value);
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.server);
    db.listReads++;
    final rows = db.records.entries
        .where((e) => e.key.startsWith('$path/') && e.value['role'] == 'member')
        .map((e) => _Doc(e.key.split('/').last, Map.of(e.value)))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final result = rows
        .where((d) => after == null || d.id.compareTo(after!) > 0)
        .take(cap)
        .toList();
    db.afterList?.call();
    return _Page(result);
  }
}

class _Directory implements AdminMemberDirectoryRepository {
  String detailName = 'Actual member';
  bool failDetails = false;
  int detailReads = 0;
  @override
  Future<AdminMemberDetails> loadDetails(String memberId) async {
    detailReads++;
    if (failDetails) throw StateError('private details failure');
    return AdminMemberDetails(
        member: AdminMemberRecord(
            id: memberId,
            name: detailName,
            email: 'member@example.test',
            status: 'active'),
        organizationId: 'o',
        branchIds: ['main']);
  }

  final requests = <(String, String, String?)>[];
  bool fail = false;
  Completer<AdminMemberPage>? pending;
  @override
  Future<AdminMemberPage> loadPage(
      {String query = '', String status = 'All', String? afterId}) async {
    requests.add((query, status, afterId));
    if (fail) throw StateError('private backend details');
    if (pending != null) return pending!.future;
    return AdminMemberPage(query == 'absent' || status == 'Suspended'
        ? []
        : const [
            AdminMemberRecord(
                id: 'm',
                name: 'Actual member',
                email: 'member@example.test',
                status: 'active')
          ]);
  }
}

class _MockAccounts extends Fake implements UserAccountRepository {
  @override
  List<UserAccount> get users => [
        UserAccount(
            'Mock Member', 'mock@example.test', 'Member', AccountStatus.active)
      ];
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late _Db db;
  late FirebaseAdminMemberDirectoryRepository repo;
  var current = true;
  setUp(() {
    db = _Db();
    current = true;
    repo = FirebaseAdminMemberDirectoryRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => current,
        firestore: db,
        auth: _Auth());
  });
  test(
      'reads only real organization members and searches name/email case insensitively',
      () async {
    db.member('a', name: 'Alice');
    db.member('b', name: 'Bob', status: 'suspended');
    expect((await repo.loadPage(query: 'ALICE')).items.single.name, 'Alice');
    expect(
        (await repo.loadPage(query: 'B@EXAMPLE', status: 'Suspended'))
            .items
            .single
            .id,
        'b');
    expect((await repo.loadPage(status: 'Active')).items.single.id, 'a');
    expect((await repo.loadPage(query: 'absent')).items, isEmpty);
  });
  test('detail reads a fresh membership and preserves absent optional fields',
      () async {
    db.member('a', name: 'Original');
    db.records['orgs/o/members/a']!['branchIds'] = ['main'];
    db.records['orgs/o/members/a']!['createdAtMillis'] = 12345;
    expect((await repo.loadDetails('a')).member.name, 'Original');
    db.records['orgs/o/members/a']!['displayName'] = 'Changed';
    final details = await repo.loadDetails('a');
    expect(details.member.name, 'Changed');
    expect(details.branchIds, ['main']);
    expect(details.createdAtMillis, 12345);
    expect(details.updatedAtMillis, isNull);
    expect(db.listReads, 0);
  });
  test('detail rejects missing, foreign-org and non-Member records', () async {
    await expectLater(repo.loadDetails('missing'), throwsStateError);
    await expectLater(repo.loadDetails('admin'), throwsStateError);
    db.member('a');
    db.records['orgs/o/members/a']!['organizationId'] = 'foreign';
    await expectLater(repo.loadDetails('a'), throwsStateError);
    await expectLater(repo.loadDetails('a/b'), throwsFormatException);
  });
  test('detail refuses a demoted Admin before reading another membership',
      () async {
    db.member('a');
    db.records['orgs/o/members/admin']!['role'] = 'coach';
    await expectLater(repo.loadDetails('a'), throwsStateError);
  });
  test('detail discards its result if canonical permissions drift during read',
      () async {
    db.member('a');
    db.afterGet = (path) {
      if (path == 'orgs/o/members/a') {
        db.records['users/admin'] = {'organizationId': 'foreign'};
      }
    };
    await expectLater(repo.loadDetails('a'), throwsStateError);
  });
  test('cursor pagination neither repeats nor drops members', () async {
    for (var i = 0; i < 27; i++) {
      db.member(i.toString().padLeft(3, '0'));
    }
    final first = await repo.loadPage(),
        second =
            await repo.loadPage(afterId: (await repo.loadPage()).nextCursor);
    expect(first.items.length, 24);
    expect(second.items.length, 3);
    expect(second.nextCursor, isNull);
    expect(
        {...first.items.map((e) => e.id), ...second.items.map((e) => e.id)}
            .length,
        27);
  });
  test('bounded search can continue beyond an empty batch', () async {
    for (var i = 0; i < 102; i++) {
      db.member(i.toString().padLeft(3, '0'));
    }
    db.member('zzz', name: 'Needle');
    final first = await repo.loadPage(query: 'needle');
    expect(first.items, isEmpty);
    expect(first.nextCursor, '099');
    expect(
        (await repo.loadPage(query: 'needle', afterId: first.nextCursor))
            .items
            .single
            .id,
        'zzz');
  });
  test(
      'rejects non-Admin, organization drift and expired edit sessions before listing',
      () async {
    for (final patch in [
      {'role': 'member'},
      {'role': 'coach'},
      {'role': 'staff'},
      {'status': 'suspended'},
      {'organizationId': 'elsewhere'}
    ]) {
      db.records['orgs/o/members/admin'] = {
        'organizationId': 'o',
        'role': 'admin',
        'status': 'active',
        ...patch
      };
      await expectLater(repo.loadPage(), throwsStateError);
    }
    expect(db.listReads, 0);
  });
  test('does not return data when permissions change during the read',
      () async {
    db.member('a');
    db.afterList =
        () => db.records['users/admin'] = {'organizationId': 'other'};
    await expectLater(repo.loadPage(), throwsStateError);
  });
  test('session invalidation remains latched and rejects malformed cursors',
      () async {
    current = false;
    await expectLater(repo.loadPage(), throwsStateError);
    current = true;
    await expectLater(repo.loadPage(), throwsStateError);
    expect(db.listReads, 0);
  });
  test('invalid cursors and filters never issue a Firestore list', () async {
    await expectLater(repo.loadPage(afterId: 'a/b'), throwsFormatException);
    await expectLater(repo.loadPage(status: 'admin'), throwsFormatException);
    expect(db.listReads, 0);
  });
  Future<void> screen(WidgetTester tester, _Directory port) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        RepositoryProvider<AdminMemberDirectoryRepository>.value(
            value: port,
            child: MaterialApp(
                theme: AppTheme.build(),
                home: const MembersScreen(live: true))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'live table searches, filters and refreshes without lifecycle actions',
      (tester) async {
    final port = _Directory();
    await screen(tester, port);
    expect(find.text('Actual member'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    await tester.enterText(find.byType(TextField), 'absent');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(port.requests.last, ('absent', 'All', null));
    expect(find.text('Actual member'), findsNothing);
    expect(find.text('No members match that search.'), findsOneWidget);
    await tester.tap(find.text('Suspended'));
    await tester.pumpAndSettle();
    expect(port.requests.last, ('absent', 'Suspended', null));
    await tester.tap(find.byTooltip('Refresh members'));
    await tester.pumpAndSettle();
    expect(port.requests.length, 4);
  });
  testWidgets('failed reads expose a sanitized retry and reload real rows',
      (tester) async {
    final port = _Directory()..fail = true;
    await screen(tester, port);
    expect(find.textContaining('Could not load members.'), findsOneWidget);
    expect(find.text('private backend details'), findsNothing);
    port.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Actual member'), findsOneWidget);
  });
  testWidgets('discard late search results when a newer search replaces them',
      (tester) async {
    final port = _Directory();
    await screen(tester, port);
    final pending = Completer<AdminMemberPage>();
    port.pending = pending;
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 350));
    port.pending = null;
    await tester.enterText(find.byType(TextField), 'absent');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    pending.complete(AdminMemberPage(const [
      AdminMemberRecord(
          id: 'old',
          name: 'Stale private result',
          email: 'old@example.test',
          status: 'active')
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Stale private result'), findsNothing);
    expect(find.text('No members match that search.'), findsOneWidget);
  });
  testWidgets('Mock Mode retains its existing account actions', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<UserAccountRepository>.value(
        value: _MockAccounts(),
        child:
            MaterialApp(theme: AppTheme.build(), home: const MembersScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Suspend account'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
  });
  testWidgets(
      'detail dialog loads and refreshes fresh records then returns to directory',
      (tester) async {
    final port = _Directory();
    await screen(tester, port);
    await tester.tap(find.byTooltip('View details for Actual member'));
    await tester.pumpAndSettle();
    expect(find.text('Member details'), findsOneWidget);
    expect(find.text('Member ID'), findsOneWidget);
    expect(find.text('Organization'), findsOneWidget);
    expect(find.text('Not recorded'), findsNWidgets(2));
    expect(port.detailReads, 1);
    port.detailName = 'Reloaded member';
    await tester.tap(find.text('Refresh details'));
    await tester.pumpAndSettle();
    expect(find.text('Reloaded member'), findsOneWidget);
    expect(port.detailReads, 2);
    expect(find.text('Suspend account'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Member details'), findsNothing);
    expect(find.text('Actual member'), findsOneWidget);
  });
  testWidgets(
      'failed detail refresh hides stale data and supports a sanitized retry',
      (tester) async {
    final port = _Directory();
    await screen(tester, port);
    await tester.tap(find.byTooltip('View details for Actual member'));
    await tester.pumpAndSettle();
    port.failDetails = true;
    await tester.tap(find.text('Refresh details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load this member.'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('private details failure'), findsNothing);
    port.failDetails = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Member ID'), findsOneWidget);
  });
}
