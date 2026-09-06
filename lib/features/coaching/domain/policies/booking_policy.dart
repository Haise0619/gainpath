/// AD-M10.1 — a coach's booking limits: at most [dailyCap] sessions per
/// day, and no booking further than [advanceDays] ahead.
class BookingPolicy {
  const BookingPolicy({this.dailyCap = 4, this.advanceDays = 30});

  final int dailyCap;
  final int advanceDays;

  bool canBookOn(DateTime day, {required int existingThatDay, DateTime? now}) {
    if (existingThatDay >= dailyCap) return false;
    final today = now ?? DateTime.now();
    final latest = DateTime(today.year, today.month, today.day).add(Duration(days: advanceDays));
    return !DateTime(day.year, day.month, day.day).isAfter(latest);
  }
}
