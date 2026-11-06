import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_data/gainpath_data.dart' show FunctionEndpointSelector;

/// Reward shop and collection use the isolated Singapore reward services.
/// Keep the membership compatibility endpoint selection independent.
HttpsCallable firebaseRewardCallable(String name) {
  final client = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
    client.useFunctionsEmulator(
      const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
          defaultValue: '127.0.0.1'),
      5001,
    );
  }
  return client.httpsCallable(name);
}

/// Creates a regional callable while retaining explicit SDK test overrides.
/// FUNCTIONS_REGION selects trusted callables; existing read aliases retain
/// their independent rollback flags. Emulator calls retain original US names.
HttpsCallable firebaseCallable(
  String name, {
  FirebaseFunctions? functions,
  HttpsCallableOptions? options,
  FunctionEndpointSelector endpoints = const FunctionEndpointSelector(),
}) {
  if (functions != null) return functions.httpsCallable(name, options: options);
  // New scoped services keep their own fixed region; canonical rollback
  // aliases and endpoint inventory remain unchanged.
  if (name == 'exerciseCatalogCommand' ||
      name == 'fypDatasetCommand' ||
      name == 'fypDatasetSessionCommand') {
    final client = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
    if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
      client.useFunctionsEmulator(
          const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
              defaultValue: '127.0.0.1'),
          const int.fromEnvironment('FIREBASE_FUNCTIONS_EMULATOR_PORT',
              defaultValue: 5001));
    }
    return client.httpsCallable(name, options: options);
  }

  if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS')) {
    final client = FirebaseFunctions.instanceFor(region: 'us-central1');
    client.useFunctionsEmulator(
      const String.fromEnvironment('FIREBASE_EMULATOR_HOST',
          defaultValue: '127.0.0.1'),
      5001,
    );
    return client.httpsCallable(name, options: options);
  }
  final endpoint = endpoints.forCommand(name);
  final client = FirebaseFunctions.instanceFor(region: endpoint.region);
  return client.httpsCallable(endpoint.name, options: options);
}

/// Explicit operation map preserves canonical behavior for ordinary accounts.
const fypScopedOperations = <String, String>{
  'getMemberBookingOptionsCommand': 'module/getMemberBookingOptionsCommand',
  'getCoachAccountSettingsCommand': 'module/getCoachAccountSettingsCommand',
  'getCoachRatingsCommand': 'module/getCoachRatingsCommand',
  'getCoachAvailabilityCommand': 'module/getCoachAvailabilityCommand',
  'getCoachRosterCommand': 'module/getCoachRosterCommand',
  'getBookingListCommand': 'module/getBookingListCommand',
  'getCoachCertificationsCommand': 'module/getCoachCertificationsCommand',
  'getCoachPublishedPhotoCommand': 'module/getCoachPublishedPhotoCommand',
  'module9MemberCommandCallable': 'module/module9MemberCommandCallable',
  'adminReportingCommand': 'module/adminReportingCommand',
  'adminWorkoutReportingCommand': 'module/adminWorkoutReportingCommand',
  'adminCheckInReportingCommand': 'module/adminCheckInReportingCommand',
  'workoutProgramCommand': 'module/workoutProgramCommand',
};

class ScopedCallableResult<T> {
  ScopedCallableResult(this.data);
  final T data;
}

class ScopedFirebaseCallable {
  ScopedFirebaseCallable(this.scope, this.name, this.functions, this.options);
  final SessionScope scope;
  final String name;
  final FirebaseFunctions? functions;
  final HttpsCallableOptions? options;
  Future<ScopedCallableResult<T>> call<T>([Object? parameters]) async {
    final operation = fypScopedOperations[name];
    if (scope.datasetScope == null || operation == null) {
      final response =
          await firebaseCallable(name, functions: functions, options: options)
              .call<T>(parameters);
      return ScopedCallableResult(response.data);
    }
    if (parameters is! Map ||
        parameters.keys.any((k) => k is! String) ||
        ['datasetId', 'cohortId', 'demoMode', 'rootPath']
            .any(parameters.containsKey)) {
      throw FirebaseFunctionsException(
          code: 'invalid-argument', message: 'Invalid scoped request.');
    }
    final response = await firebaseCallable('fypDatasetCommand',
            functions: functions, options: options)
        .call<T>(
            {'schemaVersion': 1, 'operation': operation, 'data': parameters});
    return ScopedCallableResult(response.data);
  }
}

ScopedFirebaseCallable firebaseScopedCallable(SessionScope scope, String name,
        {FirebaseFunctions? functions, HttpsCallableOptions? options}) =>
    ScopedFirebaseCallable(scope, name, functions, options);
