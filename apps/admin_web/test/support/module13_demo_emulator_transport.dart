import 'dart:async';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession;
import 'dart:convert';
import 'dart:io';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:http/http.dart' as http;

/// Test-only real Auth/Firestore REST protocol for a Flutter widget environment
/// without native Firebase plugins. Roles are read from current protected data.
class EmulatorDemoAuthGateway
    implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  EmulatorDemoAuthGateway(this.client) {
    if (Platform.environment['MODULE13_DEMO_GATEWAY'] != '127.0.0.1:15019') {
      throw StateError('Isolated demo endpoint required');
    }
  }
  final http.Client client;
  final changes = StreamController<FirebaseAuthUser?>.broadcast();
  FirebaseAuthUser? current;
  String get idToken => Platform.environment['MODULE13_DEMO_ID_TOKEN']!;
  static const project = 'demo-gainpath-module13-demo';
  Map<String, String> get headers =>
      {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'};
  Object? field(dynamic f) {
    if (f is! Map) {
      return null;
    }
    if (f.containsKey('stringValue')) {
      return f['stringValue'];
    }
    if (f.containsKey('booleanValue')) {
      return f['booleanValue'];
    }
    if (f.containsKey('integerValue')) {
      return int.parse(f['integerValue'].toString());
    }
    if (f.containsKey('arrayValue')) {
      return ((f['arrayValue'] as Map)['values'] as List? ?? [])
          .map(field)
          .toList();
    }
    return null;
  }

  Future<Map<String, Object?>> document(String path) async {
    final r = await client.get(
        Uri.parse(
            'http://127.0.0.1:18119/v1/projects/$project/databases/module13-demo/documents/$path'),
        headers: headers);
    if (r.statusCode != 200) {
      throw StateError('Current demo account could not be read');
    }
    final fields = (jsonDecode(r.body) as Map)['fields'] as Map;
    return fields.map((k, v) => MapEntry(k.toString(), field(v)));
  }

  @override
  Future<FirebaseAuthUser?> restoreUser() async {
    final r = await client.post(
        Uri.parse(
            'http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:lookup?key=emulator-only-key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}));
    if (r.statusCode != 200) {
      throw StateError('Auth Emulator identity unavailable');
    }
    final u = ((jsonDecode(r.body) as Map)['users'] as List).single as Map,
        uid = u['localId'] as String;
    final user = await document('users/$uid'),
        member = await document('orgs/gainpath/members/$uid');
    if (user['organizationId'] != 'gainpath' ||
        member['organizationId'] != 'gainpath' ||
        member['status'] != 'active') {
      throw StateError('Canonical demo membership unavailable');
    }
    current = FirebaseAuthUser(
        userId: uid,
        email: u['email'] as String,
        emailVerified: u['emailVerified'] == true,
        displayName: user['displayName'] as String?,
        claims: {
          'organizationId': 'gainpath',
          'role': member['role'],
          'status': member['status'],
          'branchIds': member['branchIds']
        });
    return current;
  }

  @override
  Stream<FirebaseAuthUser?> get userChanges => changes.stream;
  @override
  Future<FirebaseAuthUser> signIn(
          {required String email, required String password}) async =>
      (await restoreUser())!;
  @override
  Future<FirebaseAuthUser> register(
          {required String email,
          required String password,
          required String name}) =>
      Future.error(StateError('No registration in this test'));
  @override
  Future<void> sendEmailVerification() =>
      Future.error(StateError('No emails in this widget workflow'));
  @override
  Future<void> signOut() async {
    current = null;
    changes.add(null);
  }

  Future<Object?> invoke(String name, Map<String, Object?> data) async {
    String part(Object v) =>
        base64UrlEncode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
    final check = '${part({'alg': 'none'})}.${part({
          'sub': 'module13-demo-test-app',
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })}.';
    final r = await client.post(
        Uri.parse('http://127.0.0.1:15019/$project/asia-southeast1/$name'),
        headers: {...headers, 'X-Firebase-AppCheck': check},
        body: jsonEncode({'data': data}));
    final body = jsonDecode(r.body) as Map;
    if (r.statusCode != 200 || body.containsKey('error')) {
      throw StateError('Actual controlled callable refused');
    }
    return body['result'] ?? body['data'];
  }

  Module13DemoTransport transport(
          AuthSession session, bool Function() isCurrent) =>
      Module13DemoTransport(
          scope: session.scope,
          role: session.role,
          isCurrent: isCurrent,
          currentUid: () => current?.userId,
          emailVerified: () => current?.emailVerified == true,
          appCheckReady: () async => true,
          invoke: invoke);
  Future<void> dispose() async {
    await changes.close();
  }
}
