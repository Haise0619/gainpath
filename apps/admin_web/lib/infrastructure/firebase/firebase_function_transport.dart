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
