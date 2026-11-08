import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart' as legacy;
import 'package:gainpath_domain/gainpath_domain.dart'
    show PersistedBookingRecord;
import 'package:gainpath_ui/gainpath_ui.dart';

/// A display phase, not a persisted booking/payment/attendance transition.
enum CoachSessionPhase {
  confirmed,
  inProgress,
  awaitingNotes,
  pendingHold,
  holdElapsed,
  completed,
  cancelled,
  expired,
  refunded;

  String get label => switch (this) {
        confirmed => 'Confirmed',
        inProgress => 'In progress',
        awaitingNotes => 'Awaiting notes',
        pendingHold => 'Pending hold',
        holdElapsed => 'Hold time elapsed',
        completed => 'Completed',
        cancelled => 'Cancelled',
        expired => 'Expired',
        refunded => 'Refunded',
      };
  String get description => switch (this) {
        confirmed => 'This appointment is confirmed and has not started yet.',
        inProgress =>
          'The scheduled session is in progress. Notes can be published after it ends.',
        awaitingNotes =>
          'The scheduled session has ended. Publish consultation notes to mark it completed.',
        pendingHold =>
          'This is an unpaid booking hold, not a confirmed appointment.',
        holdElapsed =>
          'The hold deadline has passed. Awaiting the server to record its final outcome.',
        completed =>
          'This session is recorded as completed. Published consultation notes are read-only.',
        cancelled =>
          'This booking was cancelled. Cancellation does not confirm a refund.',
        expired =>
          'The unpaid booking hold expired before confirmation. This is not a completed session.',
        refunded =>
          'This booking is recorded as refunded and is closed. Payment details are managed separately.',
      };
  Color get color => switch (this) {
        confirmed || completed => AppColors.success,
        inProgress => AppColors.primary,
        awaitingNotes || pendingHold || holdElapsed => AppColors.warning,
        cancelled => AppColors.danger,
        expired || refunded => AppColors.inkSoft,
      };
  bool get isHistory => ![confirmed, inProgress, pendingHold].contains(this);
  bool get canCancel => this == confirmed;
  bool get canWriteNotes => this == awaitingNotes;
  bool get canViewNotes => this == completed;
  bool get canOpenConversation =>
      [confirmed, inProgress, awaitingNotes, completed].contains(this);
  bool get canViewFormHistory => canOpenConversation;
}

CoachSessionPhase coachSessionPhase(legacy.Booking booking,
    {PersistedBookingRecord? record, required int serverNowMillis}) {
  final raw = record?.rawStatus ??
      switch (booking.status) {
        legacy.BookingStatus.confirmed => 'confirmed',
        legacy.BookingStatus.completed => 'completed',
        legacy.BookingStatus.cancelled => 'cancelled',
        legacy.BookingStatus.pending => 'pending_hold',
      };
  switch (raw) {
    case 'completed':
      return CoachSessionPhase.completed;
    case 'cancelled':
      return CoachSessionPhase.cancelled;
    case 'expired':
      return CoachSessionPhase.expired;
    case 'refunded':
      return CoachSessionPhase.refunded;
    case 'pending_hold':
      return record != null && serverNowMillis >= record.holdExpiresAtMillis
          ? CoachSessionPhase.holdElapsed
          : CoachSessionPhase.pendingHold;
    default:
      final start =
          record?.startAtMillis ?? booking.start.millisecondsSinceEpoch;
      final end = record?.endAtMillis ??
          booking.start
              .add(Duration(minutes: booking.durationMin))
              .millisecondsSinceEpoch;
      return serverNowMillis < start
          ? CoachSessionPhase.confirmed
          : serverNowMillis < end
              ? CoachSessionPhase.inProgress
              : CoachSessionPhase.awaitingNotes;
  }
}

/// Only deadlines belonging to an unresolved, time-sensitive state matter.
List<int> coachSessionBoundaries(
    legacy.Booking booking, PersistedBookingRecord? record) {
  if (record != null) {
    return switch (record.rawStatus) {
      'confirmed' => [record.startAtMillis, record.endAtMillis],
      'pending_hold' => [record.holdExpiresAtMillis],
      _ => const [],
    };
  }
  return booking.status == legacy.BookingStatus.confirmed
      ? [
          booking.start.millisecondsSinceEpoch,
          booking.start
              .add(Duration(minutes: booking.durationMin))
              .millisecondsSinceEpoch
        ]
      : const [];
}
