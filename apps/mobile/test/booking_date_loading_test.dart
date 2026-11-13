import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/application/booking_date_availability.dart';
import 'booking_selection_consumer_test.dart' show SelectionOptions;

class GatedDates extends SelectionOptions {
  final gate = Completer<void>();
  int active = 0, maximum = 0;
  @override
  Future<BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes}) async {
    active++;
    if (active > maximum) maximum = active;
    try {
      await gate.future;
      return await super.load(
          coachId: coachId,
          localDate: localDate,
          durationMinutes: durationMinutes);
    } finally {
      active--;
    }
  }
}

void main() {
  test(
      'weekly checks are bounded to three concurrent reads and use the seeded day once',
      () async {
    final repo = GatedDates();
    final seed =
        await SelectionOptions().load(coachId: 'coach', durationMinutes: 60);
    final dates = BookingDateAvailability(
        repository: repo, coachId: 'coach', isCurrent: () => true);
    final load = dates.loadPage(seed);
    await Future<void>.delayed(Duration.zero);
    expect(repo.active, 3);
    expect(dates.state('2026-10-16'), BookingDateState.checking);
    repo.gate.complete();
    await load;
    expect(repo.maximum, 3);
    expect(dates.days, hasLength(7));
    expect(dates.state('2026-10-16'), BookingDateState.available);
    expect(repo.durations, hasLength(6));
    dates.dispose();
  });
  test('account drift discards late calendar results and hides the old page',
      () async {
    var current = true;
    final repo = GatedDates();
    final seed =
        await SelectionOptions().load(coachId: 'coach', durationMinutes: 60);
    final dates = BookingDateAvailability(
        repository: repo, coachId: 'coach', isCurrent: () => current);
    final load = dates.loadPage(seed);
    await Future<void>.delayed(Duration.zero);
    current = false;
    repo.gate.complete();
    await load;
    expect(dates.days, isEmpty);
    expect(dates.firstAvailable, isNull);
    expect(dates.value(seed.localDate), isNull);
    expect(dates.value('2026-10-16'), isNull);
    dates.dispose();
  });
}
