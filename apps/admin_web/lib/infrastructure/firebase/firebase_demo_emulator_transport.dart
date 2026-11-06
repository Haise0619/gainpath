import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:http/http.dart' as http;

/// Callable HTTP + real Auth Emulator ID tokens. The unsigned App Check test
/// token is decoded only by the isolated Functions Emulator, never production.
Module13DemoInvoke demoEmulatorInvoke(FirebaseAuth auth) {
  if (auth.app.options.projectId != 'demo-gainpath-module13-demo') {
    throw const Module13DemoUnavailable();
  }
  return (name, request) async {
    if (!{
      'module13DemoAdminCommand',
      'module13DemoMemberCommand',
      'module13DemoDeliveryCommand'
    }.contains(name)) {
      throw const Module13DemoUnavailable();
    }
    final user = auth.currentUser, uid = auth.currentUser?.uid;
    if (user == null) {
      throw const Module13DemoUnavailable();
    }
    final token = await user.getIdToken();
    if (auth.currentUser?.uid != uid || token == null) {
      throw const Module13DemoUnavailable();
    }
    String part(Object value) =>
        base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final check = '${part({'alg': 'none', 'typ': 'JWT'})}.${part({
          'sub': 'module13-demo-emulated-app',
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
        })}.';
    final r = await http
        .post(
            Uri.parse(
                'http://127.0.0.1:15019/demo-gainpath-module13-demo/asia-southeast1/$name'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'X-Firebase-AppCheck': check
            },
            body: jsonEncode({'data': request}))
        .timeout(const Duration(seconds: 120));
    if (r.statusCode != 200 || utf8.encode(r.body).length > 262144) {
      throw const Module13DemoUnavailable();
    }
    final body = jsonDecode(r.body);
    if (body is! Map || body.containsKey('error')) {
      throw const Module13DemoUnavailable();
    }
    return body['result'] ?? body['data'];
  };
}
