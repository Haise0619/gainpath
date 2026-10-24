import 'dart:async';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:test/test.dart';

void main() {
  test(
      'explicit CSV routes only opted-in deployed commands with original names',
      () {
    const routes = FunctionEndpointSelector(
        callablesRegion: 'us-central1',
        singaporeCallables:
            ' getCoachCertificationsCommand,googleGymConnectionCommand,createBookingPaymentCommand,getCoachCertificationsCommand ');
    for (final name in [
      'getCoachCertificationsCommand',
      'googleGymConnectionCommand',
      'createBookingPaymentCommand'
    ]) {
      final endpoint = routes.forCommand(name);
      expect(endpoint.name, name);
      expect(endpoint.region, 'asia-southeast1');
    }
    expect(routes.forCommand('getMembershipOverviewCommand').region,
        'us-central1');
    expect(
        const FunctionEndpointSelector(singaporeCallables: '')
            .forCommand('getCoachCertificationsCommand')
            .region,
        'asia-southeast1');
    expect(
        const FunctionEndpointSelector(
                callablesRegion: 'us-central1',
                singaporeCallables: 'googleGymConnectionCommand')
            .forCommand('getCoachCertificationsCommand')
            .region,
        'us-central1');
  });
  test(
      'rejects unknown, held and non-callable opt-ins before selecting any route',
      () {
    for (final name in [
      'unknownCommand',
      'getCoachCertificationsCommand,unknownCommand',
      '*',
      'verifiedRewardsCommand',
      'premiumCoachVoucherCommand',
      'paymentWebhook',
      'googleGymOAuthCallback',
      'expireBookingHolds',
      'synchronizeGoogleBooking',
      'getCoachCertificationsCommand,,getCoachRosterCommand'
    ]) {
      expect(
          () => FunctionEndpointSelector(singaporeCallables: name)
              .forCommand('getCoachRatingsCommand'),
          throwsArgumentError,
          reason: name);
    }
  });
  test(
      'existing verified read mappings and rollback flags remain authoritative',
      () {
    const routes = FunctionEndpointSelector(
        singaporeCallables:
            'getCoachRatingsCommand,getBookingListCommand,getCoachAvailabilityCommand',
        ratingsRegion: 'us-central1',
        bookingReadsRegion: 'us-central1');
    for (final name in [
      'getCoachRatingsCommand',
      'getBookingListCommand',
      'getCoachAvailabilityCommand'
    ]) {
      expect(routes.forCommand(name).name, name);
      expect(routes.forCommand(name).region, 'us-central1');
    }
  });
  test('all deployed callables select Singapore with explicit US rollback', () {
    const routes = FunctionEndpointSelector();
    final ratings = routes.forCommand('getCoachRatingsCommand');
    expect(ratings.name, 'getCoachRatingsPilotCommand');
    expect(ratings.region, 'asia-southeast1');
    final rollback =
        const FunctionEndpointSelector(ratingsRegion: 'us-central1')
            .forCommand('getCoachRatingsCommand');
    expect(rollback.name, 'getCoachRatingsCommand');
    expect(rollback.region, 'us-central1');
    for (final name in [
      'getMembershipOverviewCommand',
      'createMembershipPaymentCommand',
      'createBookingPaymentCommand',
      'listAdminBookingPaymentsCommand',
      'syncGymBookingCommand',
    ]) {
      final endpoint = routes.forCommand(name);
      expect(endpoint.name, name);
      expect(endpoint.region, 'asia-southeast1');
    }
    expect(routes.forCommand('verifiedRewardsCommand').region, 'us-central1');
    expect(
        const FunctionEndpointSelector(callablesRegion: 'us-central1')
            .forCommand('createBookingPaymentCommand')
            .region,
        'us-central1');
    expect(
        () => const FunctionEndpointSelector(ratingsRegion: 'invalid')
            .forCommand('getCoachRatingsCommand'),
        throwsArgumentError);
  });
  test('booking reads use approved replacements with independent US rollback',
      () {
    for (final entry in {
      'getBookingListCommand': 'getBookingListReadCommand',
      'getCoachAvailabilityCommand': 'getCoachAvailabilityReadCommand',
    }.entries) {
      expect(const FunctionEndpointSelector().forCommand(entry.key).region,
          'asia-southeast1');
      final selected =
          const FunctionEndpointSelector(bookingReadsRegion: 'asia-southeast1')
              .forCommand(entry.key);
      expect(selected.name, entry.value);
      expect(selected.region, 'asia-southeast1');
      final rollback =
          const FunctionEndpointSelector(bookingReadsRegion: 'us-central1')
              .forCommand(entry.key);
      expect(rollback.name, entry.key);
      expect(rollback.region, 'us-central1');
      expect(
          () => const FunctionEndpointSelector(bookingReadsRegion: 'invalid')
              .forCommand(entry.key),
          throwsArgumentError);
    }
    for (final mutation in [
      'saveCoachAvailabilityDayCommand',
      'saveCoachRosterCommand',
      'createBookingHoldCommand',
      'createBookingPaymentCommand',
      'getBookingPaymentCommand'
    ]) {
      final endpoint = const FunctionEndpointSelector().forCommand(mutation);
      expect(endpoint.name, mutation);
      expect(
          endpoint.region,
          mutation == 'createBookingHoldCommand'
              ? 'us-central1'
              : 'asia-southeast1');
    }
  });
  test(
      'overlapping reads share work only until completion, with independent keys and retry after failure',
      () async {
    final reads = InFlightRead<String>();
    final first = Completer<String>();
    var calls = 0;
    Future<String> load() {
      calls++;
      return first.future;
    }

    final a = reads.run('page', load), b = reads.run('page', load);
    expect(calls, 1);
    expect(await reads.run('other', () async => 'other'), 'other');
    first.complete('page');
    expect(await Future.wait([a, b]), ['page', 'page']);
    expect(
        await reads.run('page', () async {
          calls++;
          return 'fresh';
        }),
        'fresh');
    expect(calls, 2);
    await expectLater(
        reads.run('bad', () => throw StateError('failed')), throwsStateError);
    expect(await reads.run('bad', () async => 'recovered'), 'recovered');
    final independentSession = InFlightRead<String>();
    final pending = Completer<String>();
    final old = reads.run('scope', () => pending.future);
    expect(await independentSession.run('scope', () async => 'new session'),
        'new session');
    pending.complete('old session');
    await old;
  });
}
