import '../../workout/domain/program_enrollment.dart';

enum ProgramAdherenceStatus { completed, partial, skipped, pending, rest }

class ProgramAdherenceDay {
  const ProgramAdherenceDay(this.key, this.date, this.week, this.status);
  final String key;
  final DateTime date;
  final int week;
  final ProgramAdherenceStatus status;
}

class ProgramAdherenceSummary {
  ProgramAdherenceSummary(this.enrollment, List<ProgramAdherenceDay> days,
      {this.isCurrent = false})
      : days = List.unmodifiable(days);
  final ProgramEnrollment enrollment;
  final bool isCurrent;
  final List<ProgramAdherenceDay> days;
  int get scheduled =>
      days.where((d) => d.status != ProgramAdherenceStatus.rest).length;
  int count(ProgramAdherenceStatus status) =>
      days.where((d) => d.status == status).length;
  int get completed => count(ProgramAdherenceStatus.completed);
  int get skipped => count(ProgramAdherenceStatus.skipped);
  List<List<ProgramAdherenceDay>> get weeks => [
        for (var week = 1; week <= 4; week++)
          List.unmodifiable(days.where((d) => d.week == week))
      ];
}

/// Schedule dates are date-only; only the clock instant receives the UTC+08 offset.
DateTime programMalaysiaDate(DateTime now) {
  final local = now.toUtc().add(const Duration(hours: 8));
  return DateTime.utc(local.year, local.month, local.day);
}

int completedScheduledThisWeek(
    List<ProgramAdherenceSummary> summaries, DateTime now) {
  final today = programMalaysiaDate(now);
  final start = today.subtract(Duration(days: today.weekday - 1));
  final end = start.add(const Duration(days: 7));
  return summaries
      .expand((s) => s.days)
      .where((d) =>
          d.status == ProgramAdherenceStatus.completed &&
          !d.date.isBefore(start) &&
          d.date.isBefore(end))
      .length;
}

extension CurrentProgramPresentation on ProgramAdherenceSummary {
  List<ProgramAdherenceDay> weekAt(DateTime now) {
    final today = programMalaysiaDate(now);
    final start = today.subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return days
        .where((d) => !d.date.isBefore(start) && d.date.isBefore(end))
        .toList();
  }

  ProgramAdherenceDay? get nextUnfinished {
    final pending = days
        .where((d) =>
            d.status == ProgramAdherenceStatus.pending ||
            d.status == ProgramAdherenceStatus.partial)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return pending.firstOrNull;
  }
}
