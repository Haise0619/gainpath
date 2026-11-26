import 'dart:convert';

import 'package:web/web.dart' as web;

String _key(String scope) => 'gainpath.admin.notifications.v1.$scope';

Set<String> readSeenNotifications(String scope) {
  try {
    final data =
        jsonDecode(web.window.localStorage.getItem(_key(scope)) ?? '[]');
    if (data is List) return data.whereType<String>().take(300).toSet();
  } catch (_) {
    // Browsers can block storage. The current session still tracks read items.
  }
  return <String>{};
}

void writeSeenNotifications(String scope, Set<String> keys) {
  try {
    web.window.localStorage.setItem(_key(scope), jsonEncode(keys.toList()));
  } catch (_) {
    // Notification delivery does not depend on browser storage.
  }
}
