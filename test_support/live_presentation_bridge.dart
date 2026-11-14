// ignore_for_file: depend_on_referenced_packages, unnecessary_overrides
import 'dart:convert';
import 'dart:io';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class _DirectHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

/// Opt-in, loopback-only read bridge. No credentials or Firebase selectors enter
/// screenshots or artifacts. Both this allowlist and the bridge reject writes.
class LivePresentationBridge {
  LivePresentationBridge(this.role);
  final String role;
  int pending = 0;
  int requests = 0;
  final failures = <String>[];
  final operations = <String>[];
  late final transport = FypDatasetTransport(
      scope: SessionScope(
          userId: role == 'admin' ? 'demo-m13-admin' : 'demo-m13-member-01',
          organizationId: 'gainpath',
          datasetScope: const VerifiedDatasetScope(
              datasetId: 'fyp-v1',
              seedId: 'gainpath-fyp-v1',
              revision: 1,
              rootPath: 'orgs/gainpath/cohorts/fyp-v1')),
      isCurrent: () => true,
      invoke: (_, request) async {
        final operation = request['operation'] as String;
        final data = Map<String, Object?>.from(request['data'] as Map);
        final allowed = operation.startsWith('admin.queue.') &&
                ['list', 'detail', 'configuration', 'status']
                    .contains(operation.split('.').last) ||
            operation.startsWith('admin.insights.') ||
            operation == 'member.inbox' ||
            operation == 'member.coach' ||
            operation == 'member.routine' ||
            ['member.consent.get', 'member.consent.notice']
                .contains(operation) ||
            operation == 'member.recommendation.command' &&
                ['get', 'resolve'].contains(data['action']);
        if (!allowed) throw StateError('Read-only render refuses $operation');
        pending++;
        requests++;
        operations.add(operation);
        try {
          return await HttpOverrides.runWithHttpOverrides(() async {
            final client = HttpClient()
              ..connectionTimeout = const Duration(seconds: 30);
            try {
              final req = await client
                  .postUrl(Uri.parse('http://127.0.0.1:18340/$role'));
              req.headers.contentType = ContentType.json;
              req.write(jsonEncode({'operation': operation, 'data': data}));
              final response =
                  await req.close().timeout(const Duration(seconds: 60));
              final body = await utf8.decoder.bind(response).join();
              if (response.statusCode != 200) {
                throw StateError('Bridge request failed');
              }
              return jsonDecode(body);
            } finally {
              client.close(force: true);
            }
          }, _DirectHttp());
        } catch (error) {
          failures.add('$operation: $error');
          rethrow;
        } finally {
          pending--;
        }
      });
}
