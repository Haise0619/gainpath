import 'entities/booking.dart';

class CoachSharing {
  const CoachSharing(this.enabled, this.revision);
  final bool enabled;
  final int revision;
}

class MemberNotice {
  const MemberNotice(
      {required this.id,
      required this.title,
      required this.message,
      required this.read,
      required this.createdAt,
      this.bookingId});
  final String id, title, message;
  final bool read;
  final DateTime createdAt;
  final String? bookingId;
}

class NoticePage {
  const NoticePage(this.records, this.nextAfterId);
  final List<MemberNotice> records;
  final String? nextAfterId;
}

class CoachReportSession {
  const CoachReportSession(
      {required this.booking,
      required this.grossMinor,
      required this.coachMinor,
      required this.platformMinor,
      required this.reversedMinor,
      required this.eligible});
  final Booking booking;
  final int grossMinor, coachMinor, platformMinor, reversedMinor;
  final bool eligible;
}

class CoachReport {
  const CoachReport(
      {required this.firstDate,
      required this.throughDate,
      required this.policyVersion,
      required this.sessions,
      required this.reviewCount,
      required this.averageRating,
      required this.coachBasisPoints,
      required this.grossMinor,
      required this.coachMinor,
      required this.platformMinor,
      required this.reversedMinor});
  final String firstDate, throughDate, policyVersion;
  final List<CoachReportSession> sessions;
  final int reviewCount,
      coachBasisPoints,
      grossMinor,
      coachMinor,
      platformMinor,
      reversedMinor;
  final double? averageRating;
}

abstract class Module9Repository {
  Stream<void> watchInbox();
  Future<CoachSharing> loadSharing();
  Future<CoachSharing> saveSharing(bool enabled, int expectedRevision);
  Future<NoticePage> loadInbox({String? afterId});
  Future<void> markRead(String id);
  Future<CoachReport> loadPerformance();
}

abstract class BookingChangeSource {
  Stream<void> watchBookingChanges();
}
