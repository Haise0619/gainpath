import 'firebase_demo_emulator_transport.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../../features/recommendation/application/exercise_insights.dart';
import '../../features/recommendation/application/exercise_insights_repository.dart';
import '../../features/recommendation/application/recommendation_queue_repository.dart';

Module13DemoTransport createFirebaseDemoAdminTransport(
    {required AuthSession session,
    required bool Function() isCurrent,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    required bool emulator,
    Future<bool> Function()? appCheckReady}) {
  final binding = Module13DemoBinding(
      projectId: firestore.app.options.projectId,
      databaseId: firestore.databaseId,
      emulator: emulator);
  if (!binding.isValid ||
      session.role != AppRole.admin ||
      firestore.app.name != auth.app.name ||
      auth.app.name != functions.app.name) {
    throw const Module13DemoUnavailable();
  }
  return Module13DemoTransport(
      scope: session.scope,
      role: session.role,
      isCurrent: isCurrent,
      currentUid: () => auth.currentUser?.uid,
      emailVerified: () => auth.currentUser?.emailVerified == true,
      appCheckReady: appCheckReady ??
          () async =>
              emulator ||
              (await FirebaseAppCheck.instanceFor(app: auth.app).getToken())
                      ?.isNotEmpty ==
                  true,
      invoke: emulator
          ? demoEmulatorInvoke(auth)
          : (name, request) async => (await functions
                  .httpsCallable(name,
                      options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 60)))
                  .call<Object?>(request))
              .data);
}

class FirebaseDemoAdminRepositories {
  FirebaseDemoAdminRepositories(this.transport,{bool readOnly=false}) {
    insights = FirebaseDemoExerciseInsightsRepository(transport,readOnly:readOnly);
    queue = RpcRecommendationQueueRepository(
        organizationId: transport.scope.organizationId,
        sendsToFictionalInbox: transport.scope.datasetScope != null,
        readOnly:readOnly,
        isCurrent: () => transport.isCurrent,
        invoke: (method, data) => transport.map('admin.queue.$method', data));
  }
  final ScopedCommandTransport transport;
  late final ExerciseInsightsRepository insights;
  late final RecommendationQueueRepository queue;
  Future<Map<String, Object?>> access() => transport.map('session.access',
      {'schemaVersion': 1, 'organizationId': transport.scope.organizationId});
  Future<void> deliver(String id) async {
    final raw = await transport.map('delivery.process', {
      'schemaVersion': 1,
      'organizationId': transport.scope.organizationId,
      'recommendationId': id
    });
    const fields = {
      'schemaVersion',
      'mode',
      'organizationId',
      'recommendationId',
      'notificationId',
      'revision',
      'deliveredAtMillis',
      'status'
    };
    if (raw.length != fields.length ||
        !raw.keys.toSet().containsAll(fields) ||
        raw['schemaVersion'] != 1 ||
        raw['mode'] != 'synthetic_local' ||
        raw['organizationId'] != transport.scope.organizationId ||
        raw['recommendationId'] != id ||
        raw['notificationId'] != 'recommendation-$id' ||
        raw['status'] != 'delivered' ||
        raw['revision'] is! int ||
        (raw['revision'] as int) < 1 ||
        raw['deliveredAtMillis'] is! int ||
        (raw['deliveredAtMillis'] as int) < 1) {
      throw const Module13DemoUnavailable();
    }
  }
}

class FirebaseDemoExerciseInsightsRepository
    implements ExerciseInsightsRepository,InsightsReadOnlyPresentation {
  FirebaseDemoExerciseInsightsRepository(this.transport,{this.readOnly=false});
  @override
  final bool readOnly;
  final ScopedCommandTransport transport;
  @override
  String get organizationId => transport.scope.organizationId;
  @override
  bool get enabled => true;
  @override
  bool get fixtureOnly => true;
  @override
  bool get isCurrent => transport.isCurrent;
  @override
  Future<Object?> load(ExerciseInsightsQuery query) {
    if (query.organizationId != organizationId) {
      throw const ExerciseInsightsUnavailable();
    }
    return transport.call('admin.insights', query.toJson());
  }

  @override
  Future<InsightsConfigurationOptions> configuration() async {
    final raw = await transport.map('admin.configuration.choices',
        {'schemaVersion': 1, 'organizationId': organizationId});
    const keys = {
      'schemaVersion',
      'organizationId',
      'revision',
      'selectedPolicyIds',
      'availablePolicies'
    };
    if (raw.length != keys.length ||
        !raw.keys.toSet().containsAll(keys) ||
        raw['schemaVersion'] != 1 ||
        raw['organizationId'] != organizationId ||
        raw['revision'] is! int ||
        (raw['revision'] as int) < 0 ||
        raw['selectedPolicyIds'] is! List ||
        raw['availablePolicies'] is! List) {
      throw const FormatException('Invalid reviewed policy choices.');
    }
    final selected = (raw['selectedPolicyIds'] as List).map(_id).toList();
    final choices = (raw['availablePolicies'] as List).map((value) {
      if (value is! Map ||
          value.length != 3 ||
          !value.keys
              .toSet()
              .containsAll(['policyId', 'title', 'definition'])) {
        throw const FormatException('Invalid reviewed policy.');
      }
      return ReviewedPolicyChoice(
          policyId: _id(value['policyId']),
          title: _text(value['title'], 200),
          definition: _text(value['definition'], 1200));
    }).toList();
    if (choices.length > 50 ||
        choices.map((c) => c.policyId).toSet().length != choices.length ||
        selected.toSet().length != selected.length ||
        selected.any((id) => !choices.any((c) => c.policyId == id))) {
      throw const FormatException('Invalid policy selection.');
    }
    return InsightsConfigurationOptions(
        revision: raw['revision'] as int,
        selectedPolicyIds: selected,
        availablePolicies: choices);
  }

  @override
  Future<int> saveConfiguration(int revision, List<String> ids) async {
    if(readOnly)throw const ExerciseInsightsUnavailable();
    if (revision < 0 || ids.length > 50 || ids.toSet().length != ids.length) {
      throw const ExerciseInsightsUnavailable();
    }
    final raw = await transport.map('admin.configuration.save', {
      'schemaVersion': 1,
      'organizationId': organizationId,
      'commandId': 'demo-config-${DateTime.now().microsecondsSinceEpoch}',
      'expectedRevision': revision,
      'policyIds': ids.map(_id).toList()
    });
    if (raw['revision'] != revision + 1) {
      throw const FormatException('Configuration save not confirmed.');
    }
    return raw['revision'] as int;
  }

  static String _id(Object? value) {
    final s = _text(value, 128);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(s)) {
      throw const FormatException('Invalid policy identity.');
    }
    return s;
  }

  static String _text(Object? value, int max) {
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > max ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      throw const FormatException('Invalid policy text.');
    }
    return value;
  }
}
