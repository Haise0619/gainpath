import 'package:flutter/material.dart' show TimeOfDay;

/// AD-M10.1 — one weekday's recurring working window. [start]/[end]/
/// [active] are all mutable and edited directly (real time pickers, not
/// static display text), the same "mutate the seed in place" pattern
/// used throughout this app's other mutable records.
class WorkingDay {
  final String day;
  TimeOfDay start;
  TimeOfDay end;
  bool active;
  WorkingDay(this.day, this.start, this.end, this.active);
}

/// AD-M10.1 — a single time-off entry. [type] distinguishes a recurring
/// daily interruption (a break) from a whole day being unavailable (an
/// off-day or approved leave) — members shouldn't be able to book into
/// any of the three, but they read and are edited differently.
enum BlockType { breakTime, offDay, leave }

extension BlockTypeLabel on BlockType {
  String get label => switch (this) {
        BlockType.breakTime => 'Break',
        BlockType.offDay => 'Off-day',
        BlockType.leave => 'Leave',
      };
}

class BlockedSlot {
  final String id;
  BlockType type;
  String reason;
  DateTime date;
  bool fullDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  BlockedSlot({
    required this.id,
    required this.type,
    required this.reason,
    required this.date,
    required this.fullDay,
    this.startTime,
    this.endTime,
  });
}
