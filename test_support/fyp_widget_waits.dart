// Shared test-only wait helper uses each Flutter app's dependencies.
// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives HTTP futures started in a widget's fake zone without starving their
/// continuations inside an enclosing runAsync call. No unbounded await occurs.
Future<T> pumpFypFuture<T>(WidgetTester tester, Future<T> Function() action,
    {required String description, int maximumPumps = 1200}) async {
  T? result;
  Object? error;
  StackTrace? stack;
  var complete = false;
  unawaited(Future<T>.sync(action).then((value) {
    result = value;
    complete = true;
  }, onError: (Object value, StackTrace trace) {
    error = value;
    stack = trace;
    complete = true;
  }));
  for (var i = 0; i < maximumPumps && !complete; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 100));
    final exception = tester.takeException();
    if (exception != null) throw exception;
  }
  if (!complete) fail('$description exceeded its bounded HTTP wait.');
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return result as T;
}

/// Waits for an observable result, not an absence of animation. Authenticated
/// HTTP work can remain in flight while the login displays plain status text.
Future<void> waitForFypWidget(WidgetTester tester, Finder target,
    {required String description,
    int maximumPumps = 1200,
    String Function()? diagnostics}) async {
  for (var i = 0; i < maximumPumps; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 100));
    final exception = tester.takeException();
    if (exception != null) throw exception;
    if (target.evaluate().isNotEmpty) return;
  }
  final password = Platform.environment['FYP_EMULATOR_PASSWORD'];
  final feedback = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .where((value) => [
            'Signing in',
            'Unable',
            'Could not',
            'This account',
            'Your session',
            'Emulator',
            'unavailable'
          ].any(value.contains))
      .map((value) =>
          password == null ? value : value.replaceAll(password, '[redacted]'))
      .take(8)
      .join(' | ');
  fail('$description did not appear after $maximumPumps bounded pumps. '
      'Signing-in status visible: ${find.textContaining('Signing in').evaluate().isNotEmpty}. '
      'Visible loaders: circular=${find.byType(CircularProgressIndicator).evaluate().length}, linear=${find.byType(LinearProgressIndicator).evaluate().length}. '
      'Loader/chart widget types: ${tester.allWidgets.map((widget) => widget.runtimeType.toString()).where((name) => name.contains('Progress') || name.contains('Avatar') || name.contains('Chart')).toSet().take(16).join(', ')}. '
      'Request progress: ${diagnostics?.call() ?? '(not applicable)'}. '
      'Visible authentication feedback: ${feedback.isEmpty ? '(none)' : feedback}');
}
