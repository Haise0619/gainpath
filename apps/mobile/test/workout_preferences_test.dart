import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/workout/application/workout_preferences_controller.dart';
import 'package:gainpath_mobile/infrastructure/local/file_workout_preferences.dart';

final scope = SessionScope(userId: 'one', organizationId: 'gym');

class MemoryWorkoutPreferencesStore implements WorkoutPreferencesStore {
  Map<String, Object?>? value;
  bool failWrites = false;
  Completer<void>? readGate, writeGate;
  @override
  Future<Map<String, Object?>?> read() async {
    await readGate?.future;
    return value;
  }

  @override
  Future<void> write(Map<String, Object?> next) async {
    await writeGate?.future;
    if (failWrites) throw StateError('disk unavailable');
    value = Map.of(next);
  }
}

void main() {
  test('first use requires consent and defaults are explicit', () async {
    final c = WorkoutPreferencesController(
        scope: scope, store: MemoryWorkoutPreferencesStore());
    await c.load();
    expect(c.validConsent, isFalse);
    expect(c.autoContinue, isTrue);
    expect(c.suggestedRestSeconds, 30);
    await c.grantConsent();
    expect(c.validConsent, isTrue);
    expect(c.acceptedAt, isNotNull);
  });

  test(
      'durable consent and preferences reopen only for the same account and version',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath-preferences-');
    addTearDown(() => directory.delete(recursive: true));
    WorkoutPreferencesController create(SessionScope s,
            {String version = WorkoutPreferencesController.consentVersion}) =>
        WorkoutPreferencesController(
            scope: s,
            store: FileWorkoutPreferences(directory: directory, scope: s),
            requiredConsentVersion: version);
    final first = create(scope);
    await first.load();
    await first.grantConsent();
    await first.updatePreferences(
        autoContinue: false, suggestedRestSeconds: 45);
    final reopened = create(scope);
    await reopened.load();
    expect(reopened.validConsent, isTrue);
    expect(reopened.autoContinue, isFalse);
    expect(reopened.suggestedRestSeconds, 45);
    final other = create(SessionScope(userId: 'two', organizationId: 'gym'));
    await other.load();
    expect(other.validConsent, isFalse);
    final changedVersion = create(scope, version: 'material-update');
    await changedVersion.load();
    expect(changedVersion.validConsent, isFalse);
    await reopened.withdrawConsent();
    final withdrawn = create(scope);
    await withdrawn.load();
    expect(withdrawn.validConsent, isFalse);
    expect(withdrawn.autoContinue, isFalse);
  });

  test(
      'withdrawal immediately notifies capture listeners and failed writes stay closed',
      () async {
    final store = MemoryWorkoutPreferencesStore();
    final c = WorkoutPreferencesController(scope: scope, store: store);
    await c.load();
    await c.grantConsent();
    var revoked = false;
    c.addListener(() {
      if (!c.validConsent) revoked = true;
    });
    store.failWrites = true;
    final withdrawal = c.withdrawConsent();
    expect(c.validConsent, isFalse);
    expect(revoked, isTrue);
    await expectLater(withdrawal, throwsStateError);
    expect(c.validConsent, isFalse);
    expect(c.error, isNotNull);
  });

  test('foreign scope and malformed data cannot provide consent', () async {
    final store = MemoryWorkoutPreferencesStore();
    final first = WorkoutPreferencesController(scope: scope, store: store);
    await first.load();
    await first.grantConsent();
    final foreign = WorkoutPreferencesController(
        scope: SessionScope(userId: 'other', organizationId: 'gym'),
        store: store);
    await foreign.load();
    expect(foreign.validConsent, isFalse);
    store.value = {'schemaVersion': 999, 'consentVersion': '1'};
    final malformed = WorkoutPreferencesController(scope: scope, store: store);
    await malformed.load();
    expect(malformed.validConsent, isFalse);
  });

  test('withdrawal wins over an in-flight grant and can retry persistence',
      () async {
    final store = MemoryWorkoutPreferencesStore();
    final c = WorkoutPreferencesController(scope: scope, store: store);
    await c.load();
    store.writeGate = Completer<void>();
    final grant = c.grantConsent();
    await Future<void>.delayed(Duration.zero);
    final withdraw = c.withdrawConsent();
    store.writeGate!.complete();
    await grant;
    await withdraw;
    expect(c.validConsent, isFalse);
    final reopened = WorkoutPreferencesController(scope: scope, store: store);
    await reopened.load();
    expect(reopened.validConsent, isFalse);
    await c.grantConsent();
    store.failWrites = true;
    await expectLater(c.withdrawConsent(), throwsStateError);
    store.failWrites = false;
    await c.withdrawConsent();
    expect(store.value!['consentVersion'], isNull);
  });

  test('withdrawal during initial load cancels a waiting grant', () async {
    final store = MemoryWorkoutPreferencesStore()..readGate = Completer<void>();
    final c = WorkoutPreferencesController(scope: scope, store: store);
    final grant = c.grantConsent();
    final withdrawal = c.withdrawConsent();
    store.readGate!.complete();
    await grant;
    await withdrawal;
    expect(c.validConsent, isFalse);
    expect(store.value!['consentVersion'], isNull);
  });

  test(
      'startup withdrawal keeps the account rest and auto-continue preferences',
      () async {
    final store = MemoryWorkoutPreferencesStore();
    final previous = WorkoutPreferencesController(scope: scope, store: store);
    await previous.load();
    await previous.grantConsent();
    await previous.updatePreferences(
        autoContinue: false, suggestedRestSeconds: 90);
    final reopened = WorkoutPreferencesController(scope: scope, store: store);
    await reopened.withdrawConsent();
    expect(reopened.validConsent, isFalse);
    expect(reopened.autoContinue, isFalse);
    expect(reopened.suggestedRestSeconds, 90);
    expect(store.value!['consentVersion'], isNull);
  });
}
