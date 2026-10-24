import 'package:gainpath_domain/coaching.dart';

/// Local draft preview only. Trusted booking options remain server-authoritative.
/// Existing custom dates retain precedence; never overwrite reservation pins.
List<DatedCoachWindow> previewScheduledWindows({
  required CoachAvailabilityDay day,
  required CoachWeeklyDay? weeklyDay,
  required bool weeklyChanged,
}) {
  if (!weeklyChanged || (day.revision ?? 0) > 0 || weeklyDay == null) {
    return day.windows;
  }
  if (!weeklyDay.isActive) return const [];
  final windows = <DatedCoachWindow>[];
  for (var i = 0; i + 1 < day.boundaries.length; i++) {
    final boundary = day.boundaries[i], next = day.boundaries[i + 1];
    final match = RegExp(r'^(\d{2}):(\d{2})').firstMatch(boundary.label);
    if (match == null || next.atMillis - boundary.atMillis != 1800000) continue;
    final minute = int.parse(match[1]!) * 60 + int.parse(match[2]!);
    if (minute < weeklyDay.startMinute || minute >= weeklyDay.endMinute) {
      continue;
    }
    final previous = windows.lastOrNull;
    if (previous?.endAtMillis == boundary.atMillis) {
      windows[windows.length - 1] = DatedCoachWindow(
          branchId: weeklyDay.branchId,
          startAtMillis: previous!.startAtMillis,
          endAtMillis: next.atMillis);
    } else {
      windows.add(DatedCoachWindow(
          branchId: weeklyDay.branchId,
          startAtMillis: boundary.atMillis,
          endAtMillis: next.atMillis));
    }
  }
  return windows;
}
