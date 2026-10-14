import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_data/gainpath_data.dart'
    show CreateBookingHoldRequestDto;
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_booking_repository.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  FirebaseAppCheckReadiness ready() => FirebaseAppCheckReadiness(
      mode: 'production',
      supported: true,
      activate: (_) async {},
      token: () async => 'synthetic-unit-token');
  test('off and release debug never activate; setup failure stays unavailable',
      () async {
    var calls = 0;
    for (final mode in ['off', 'debug', 'unknown']) {
      final readiness = FirebaseAppCheckReadiness(
          mode: mode,
          release: true,
          supported: true,
          activate: (_) async {
            calls++;
          },
          token: () async => 'x');
      expect(await readiness.ensureReady(), false);
    }
    expect(calls, 0);
    final failed = FirebaseAppCheckReadiness(
        mode: 'production',
        supported: true,
        activate: (_) async => throw StateError('private'),
        token: () async => 'x');
    await failed.initialize();
    expect(await failed.ensureReady(), false);
  });
  test('scope drift during token await prevents callable', () async {
    var current = true;
    var calls = 0;
    final token = Completer<String?>();
    final tokenStarted = Completer<void>();
    final source = FirebaseBookingRepository(
        scope: SessionScope(userId: 'member', organizationId: 'org'),
        isCurrent: () => current,
        currentUid: () => 'member',
        readiness: FirebaseAppCheckReadiness(
            mode: 'debug',
            supported: true,
            activate: (_) async {},
            token: () {
              tokenStarted.complete();
              return token.future;
            }),
        call: (_, __) async {
          calls++;
          return {};
        });
    final future = source.load(coachId: 'coach', durationMinutes: 30);
    await tokenStarted.future;
    current = false;
    token.complete('ready');
    await expectLater(future, throwsA(isA<BookingException>()));
    expect(calls, 0);
  });
  test('Member list accepts own old branch and rejects another member',
      () async {
    var payload = pageJson();
    final repository = FirebaseBookingListRepository(
        scope: SessionScope(userId: 'member', organizationId: 'org'),
        role: AppRole.member,
        branchIds: const [],
        isCurrent: () => true,
        currentUid: () => 'member',
        call: (_, __) async => payload);
    expect((await repository.load()).records.single.branchId, 'removed-branch');
    payload = pageJson(memberId: 'other');
    await expectLater(repository.load(), throwsA(isA<BookingException>()));
  });
  test(
      'create transports exact fields; response must match intent and pending status',
      () async {
    String? receivedName;
    Map<String, dynamic>? received;
    var response = <String, dynamic>{
      'schemaVersion': 1,
      'requestId': 'intent',
      'bookingId': 'booking',
      'status': 'pending_hold',
      'holdExpiresAtMillis': 1791936600000
    };
    final repository = FirebaseBookingRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: ready(),
        call: (name, input) async {
          receivedName = name;
          received = input;
          return response;
        });
    const request = CreateBookingHoldRequestDto(
        requestId: 'intent',
        organizationId: 'org',
        memberId: 'member',
        branchId: 'branch',
        coachId: 'coach',
        startAtMillis: 1792022400000,
        durationMinutes: 30);
    expect((await repository.createHold(request)).bookingId, 'booking');
    expect(receivedName, 'createBookingHold');
    expect(received, request.toJson());
    expect(received!.length, 8);
    response = {...response, 'requestId': 'different'};
    await expectLater(
        repository.createHold(request), throwsA(isA<BookingException>()));
    response = {...response, 'requestId': 'intent', 'status': 'confirmed'};
    await expectLater(
        repository.createHold(request), throwsA(isA<BookingException>()));
  });
  test('wrong member and missing token prevent writes, SDK errors are safe',
      () async {
    var calls = 0;
    final repository = FirebaseBookingRepository(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'member',
        readiness: FirebaseAppCheckReadiness(
            mode: 'production',
            supported: true,
            activate: (_) async {},
            token: () async => ''),
        call: (_, __) async {
          calls++;
          throw StateError('secret URL');
        });
    for (final member in ['other', 'member']) {
      await expectLater(
          repository.createHold(CreateBookingHoldRequestDto(
              requestId: 'intent',
              organizationId: 'org',
              memberId: member,
              branchId: 'branch',
              coachId: 'coach',
              startAtMillis: 1792022400000,
              durationMinutes: 30)),
          throwsA(isA<BookingException>()));
    }
    expect(calls, 0);
    final broken = FirebaseBookingListRepository(
        scope: scope,
        role: AppRole.member,
        branchIds: [],
        isCurrent: () => true,
        currentUid: () => 'member',
        call: (_, __) async => throw StateError('secret URL'));
    await expectLater(
        broken.load(),
        throwsA(predicate((error) =>
            error is BookingException &&
            !error.toString().contains('secret'))));
  });
  test(
      'Coach rows require captured owner and branches; stale SDK result discarded',
      () async {
    var current = true;
    final completion = Completer<Map<String, dynamic>>();
    final repository = FirebaseBookingListRepository(
        scope: SessionScope(userId: 'coach', organizationId: 'org'),
        role: AppRole.coach,
        branchIds: ['branch'],
        isCurrent: () => current,
        currentUid: () => 'coach',
        call: (_, __) => completion.future);
    final result = repository.load();
    current = false;
    completion.complete(pageJson());
    await expectLater(result, throwsA(isA<BookingException>()));
    final wrongBranch = FirebaseBookingListRepository(
        scope: SessionScope(userId: 'coach', organizationId: 'org'),
        role: AppRole.coach,
        branchIds: ['branch'],
        isCurrent: () => true,
        currentUid: () => 'coach',
        call: (_, __) async => pageJson());
    await expectLater(wrongBranch.load(), throwsA(isA<BookingException>()));
  });
}

Map<String, dynamic> pageJson({String memberId = 'member'}) => {
      'schemaVersion': 1,
      'serverNowMillis': 1791936600001,
      'timeZone': 'Asia/Kuala_Lumpur',
      'firstLocalDate': '2026-10-14',
      'throughLocalDate': '2026-11-13',
      'records': [
        {
          'schemaVersion': 1,
          'bookingId': 'booking',
          'organizationId': 'org',
          'memberId': memberId,
          'coachId': 'coach',
          'branchId': 'removed-branch',
          'requestId': 'intent',
          'startAtMillis': 1792022400000,
          'endAtMillis': 1792024200000,
          'durationMinutes': 30,
          'status': 'pending_hold',
          'holdExpiresAtMillis': 1791936600000,
          'localDate': '2026-10-15',
          'timeZone': 'Asia/Kuala_Lumpur',
          'policyVersion': 'v1',
          'createdAtMillis': 1791936000000,
          'startLabel': '08:00 GMT+8',
          'endLabel': '08:30 GMT+8',
          'expiryLabel': '2026-10-14 08:10 GMT+8'
        }
      ]
    };
