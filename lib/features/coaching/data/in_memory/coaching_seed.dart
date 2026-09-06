import 'package:flutter/material.dart' show TimeOfDay;
import 'package:gainpath/features/coaching/domain/entities/availability.dart';
import 'package:gainpath/features/coaching/domain/entities/booking.dart';
import 'package:gainpath/features/coaching/domain/enums/booking_status.dart';
import 'package:gainpath/features/identity/data/in_memory/identity_seed.dart';

/// In-memory seed data for the coaching feature (frontend prototype).
class CoachingSeed {
  /// The single source of truth for every booking in the system, coach or
  /// member side. `memberBookings` and `coachRoster` below are filtered
  /// *views* over this one list, not separate data — Jason Lim (c1) and
  /// ZhengYang's actual shared session is one `Booking` object here, not
  /// two disconnected copies that could drift out of sync. That's what
  /// makes coach↔member messaging real: a reply either side adds lands in
  /// the same `messages` list the other side reads.
  static final allBookings = <Booking>[
    Booking(
      id: 'bk1',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().add(const Duration(days: 2, hours: 3)),
      branch: 'GainPath Kulim',
      status: BookingStatus.confirmed,
      fee: 120,
      messages: [
        BookingMessage('Member', 'Hi Jason, should I bring my own knee sleeves?',
            DateTime.now().subtract(const Duration(hours: 5))),
        BookingMessage(
            'Coach',
            'Not necessary, but bring them if you have them — we will be doing heavy squats.',
            DateTime.now().subtract(const Duration(hours: 4))),
      ],
    ),
    Booking(
      id: 'bk2',
      coachId: 'c2',
      coachName: 'Priya Menon',
      memberName: 'ZhengYang',
      start: DateTime.now().add(const Duration(days: 6)),
      branch: 'GainPath Sungai Petani',
      status: BookingStatus.confirmed,
      fee: 140,
    ),
    Booking(
      id: 'bk3',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 9)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
      notes: 'Good squat depth this session. Work on keeping the chest up during the ascent.',
      rated: true,
    ),
    Booking(
      id: 'bk4',
      coachId: 'c3',
      coachName: 'Hafiz Aziz',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 20)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 110,
    ),
    Booking(
      id: 'bk5',
      coachId: 'c4',
      coachName: 'Michelle Chan',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 3)),
      branch: 'GainPath Sungai Petani',
      status: BookingStatus.cancelled,
      fee: 130,
      cancellationReason: 'Member requested — scheduling conflict.',
    ),
    Booking(
      id: 'bk6',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().add(const Duration(days: 2, hours: 5)),
      branch: 'GainPath Kulim',
      status: BookingStatus.confirmed,
      fee: 120,
      messages: [
        BookingMessage('Member', 'Can we push my session 30 minutes later?',
            DateTime.now().subtract(const Duration(hours: 20))),
      ],
    ),
    Booking(
      id: 'bk7',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().add(const Duration(days: 4)),
      branch: 'GainPath Kulim',
      status: BookingStatus.pending,
      fee: 120,
    ),
    Booking(
      id: 'bk8',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Farid Zainal',
      start: DateTime.now().subtract(const Duration(days: 1)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    // ---- Additional history for Jason Lim (c1), spanning the last ~7
    // weeks, so the Earnings screen's weekly chart reflects real booking
    // dates rather than an illustrative static array. Deliberately spread
    // 2-3 sessions per week rather than aligned to exact week boundaries —
    // the chart buckets these by real calendar week itself, so the exact
    // spread only needs to be plausible, not hand-aligned.
    Booking(
      id: 'bk9',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 4)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk10',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().subtract(const Duration(days: 12)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk11',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Farid Zainal',
      start: DateTime.now().subtract(const Duration(days: 15)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk12',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 18)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk13',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 22)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk14',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().subtract(const Duration(days: 25)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk15',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Aina Rahman',
      start: DateTime.now().subtract(const Duration(days: 26)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk16',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 29)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk17',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Farid Zainal',
      start: DateTime.now().subtract(const Duration(days: 33)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk18',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 36)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk19',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Kevin Tan',
      start: DateTime.now().subtract(const Duration(days: 39)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk20',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().subtract(const Duration(days: 43)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk21',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 46)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
    Booking(
      id: 'bk22',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Aina Rahman',
      start: DateTime.now().subtract(const Duration(days: 47)),
      branch: 'GainPath Kulim',
      status: BookingStatus.completed,
      fee: 120,
    ),
  ];

  /// A member's own bookings, across every coach.
  static List<Booking> get memberBookings =>
      allBookings.where((b) => b.memberName == IdentitySeed.memberName).toList();

  /// The signed-in coach's own client roster, across every member.
  static List<Booking> get coachRoster =>
      allBookings.where((b) => b.coachId == IdentitySeed.currentCoach.id).toList();

  static final workingDays = <WorkingDay>[
    WorkingDay('Monday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 17, minute: 0), true),
    WorkingDay('Tuesday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 17, minute: 0), true),
    WorkingDay('Wednesday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 17, minute: 0), true),
    WorkingDay('Thursday', const TimeOfDay(hour: 10, minute: 0), const TimeOfDay(hour: 19, minute: 0), true),
    WorkingDay('Friday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 15, minute: 0), true),
    WorkingDay('Saturday', const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 13, minute: 0), true),
    WorkingDay('Sunday', const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 13, minute: 0), false),
  ];

  static final blockedSlots = <BlockedSlot>[
    BlockedSlot(
      id: 'bl1',
      type: BlockType.leave,
      reason: 'Medical leave',
      date: DateTime.now().add(const Duration(days: 5)),
      fullDay: true,
    ),
    BlockedSlot(
      id: 'bl2',
      type: BlockType.breakTime,
      reason: 'Lunch break',
      date: DateTime.now().add(const Duration(days: 1)),
      fullDay: false,
      startTime: const TimeOfDay(hour: 13, minute: 0),
      endTime: const TimeOfDay(hour: 14, minute: 0),
    ),
  ];

  static int dailyBookingCap = 4;

  static int advanceBookingDays = 30;
}
