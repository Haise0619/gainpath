import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart' show FunctionEndpointSelector;
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_function_transport.dart';

class RecordingFunctions implements FirebaseFunctions {
  String? calledName;
  HttpsCallableOptions? calledOptions;
  final callable = TestCallable();
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    calledName = name;
    calledOptions = options;
    return callable;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCallable implements HttpsCallable {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'explicit SDK retains logical read name and options without default Firebase initialization',
      () {
    final functions = RecordingFunctions();
    final options = HttpsCallableOptions(timeout: const Duration(seconds: 55));
    final callable = firebaseCallable('getCoachRatingsCommand',
        functions: functions,
        options: options,
        endpoints: const FunctionEndpointSelector(
            singaporeCallables: 'invalidCommand'));
    expect(callable, same(functions.callable));
    expect(functions.calledName, 'getCoachRatingsCommand');
    expect(functions.calledOptions?.timeout, const Duration(seconds: 55));
  });
}
