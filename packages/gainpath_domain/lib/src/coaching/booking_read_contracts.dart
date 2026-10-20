import '../coaching.dart' show BookingStatus;
import '../identity.dart' show SessionScope;
import 'booking_wire_validation.dart';

class BookingOption {
  BookingOption(
      {required this.branchId,
      required this.startAtMillis,
      required this.endAtMillis,
      required this.startLabel,
      required this.endLabel}) {
    bookingId(branchId);
    bookingText(startLabel, max: 80);
    bookingText(endLabel, max: 80);
    final minutes = (endAtMillis - startAtMillis) ~/ 60000;
    bookingInterval(startAtMillis, endAtMillis, minutes);
  }
  final String branchId, startLabel, endLabel;
  final int startAtMillis, endAtMillis;
  DateTime get startAt =>
      DateTime.fromMillisecondsSinceEpoch(startAtMillis, isUtc: true);
  DateTime get endAt =>
      DateTime.fromMillisecondsSinceEpoch(endAtMillis, isUtc: true);
  factory BookingOption.fromJson(Map<String, dynamic> data) {
    bookingShape(data,
        ['branchId', 'startAtMillis', 'endAtMillis', 'startLabel', 'endLabel']);
    return BookingOption(
        branchId: bookingId(data['branchId']),
        startAtMillis: bookingInt(data['startAtMillis']),
        endAtMillis: bookingInt(data['endAtMillis']),
        startLabel: bookingText(data['startLabel'], max: 80),
        endLabel: bookingText(data['endLabel'], max: 80));
  }
  Map<String, dynamic> toJson() => {
        'branchId': branchId,
        'startAtMillis': startAtMillis,
        'endAtMillis': endAtMillis,
        'startLabel': startLabel,
        'endLabel': endLabel
      };
}

class BookingOptionsContext {
  BookingOptionsContext(
      {required this.coachId,
      required this.durationMinutes,
      required this.serverNowMillis,
      required this.todayLocalDate,
      required this.localDate,
      required this.timeZone,
      required this.throughLocalDate,
      required List<String> permittedBranchIds,
      required List<BookingOption> options,
      this.unavailableReason})
      : permittedBranchIds = List.unmodifiable(permittedBranchIds),
        options = List.unmodifiable(options) {
    bookingId(coachId);
    bookingDuration(durationMinutes);
    bookingInt(serverNowMillis);
    bookingDate(todayLocalDate);
    bookingDate(localDate);
    bookingDate(throughLocalDate);
    bookingTimeZone(timeZone);
    final first = DateTime.parse('${todayLocalDate}T00:00:00Z');
    final last = DateTime.parse('${throughLocalDate}T00:00:00Z');
    final advanceDays = last.difference(first).inDays;
    if (advanceDays < 1 ||
        advanceDays > 30 ||
        localDate.compareTo(todayLocalDate) < 0 ||
        localDate.compareTo(throughLocalDate) > 0 ||
        permittedBranchIds.isEmpty ||
        permittedBranchIds.length > 8 ||
        permittedBranchIds.toSet().length != permittedBranchIds.length ||
        options.length > 52) {
      invalidBookingData();
    }
    for (final id in permittedBranchIds) {
      bookingId(id);
    }
    if (options.isEmpty
        ? !['no_open_times', 'daily_limit'].contains(unavailableReason)
        : unavailableReason != null) {
      invalidBookingData();
    }
    final identities = <String>{};
    for (final option in options) {
      if (!permittedBranchIds.contains(option.branchId) ||
          option.startAtMillis <= serverNowMillis ||
          option.endAtMillis - option.startAtMillis !=
              durationMinutes * 60000 ||
          !identities.add('${option.branchId}:${option.startAtMillis}')) {
        invalidBookingData();
      }
    }
  }
  final String coachId, todayLocalDate, localDate, timeZone, throughLocalDate;
  final String? unavailableReason;
  final int durationMinutes, serverNowMillis;
  final List<String> permittedBranchIds;
  final List<BookingOption> options;
  int get schemaVersion => 1;
  factory BookingOptionsContext.fromJson(Map<String, dynamic> data,
      {String? expectedCoachId,
      int? expectedDurationMinutes,
      String? expectedLocalDate}) {
    bookingShape(data, [
      'schemaVersion',
      'coachId',
      'durationMinutes',
      'serverNowMillis',
      'todayLocalDate',
      'localDate',
      'timeZone',
      'throughLocalDate',
      'permittedBranchIds',
      'options'
    ], [
      'unavailableReason'
    ]);
    bookingVersion(data['schemaVersion']);
    final coach = bookingId(data['coachId']);
    final duration = bookingDuration(data['durationMinutes']);
    final date = bookingDate(data['localDate']);
    if ((expectedCoachId != null && coach != expectedCoachId) ||
        (expectedDurationMinutes != null &&
            duration != expectedDurationMinutes) ||
        (expectedLocalDate != null && date != expectedLocalDate) ||
        (data.containsKey('unavailableReason') &&
            data['unavailableReason'] is! String)) {
      invalidBookingData();
    }
    return BookingOptionsContext(
        coachId: coach,
        durationMinutes: duration,
        serverNowMillis: bookingInt(data['serverNowMillis']),
        todayLocalDate: bookingDate(data['todayLocalDate']),
        localDate: date,
        timeZone: bookingTimeZone(data['timeZone']),
        throughLocalDate: bookingDate(data['throughLocalDate']),
        permittedBranchIds:
            bookingList(data['permittedBranchIds'], bookingId, max: 8),
        options: bookingList(
            data['options'], (raw) => BookingOption.fromJson(bookingMap(raw)),
            max: 52),
        unavailableReason: data['unavailableReason']);
  }
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'coachId': coachId,
        'durationMinutes': durationMinutes,
        'serverNowMillis': serverNowMillis,
        'todayLocalDate': todayLocalDate,
        'localDate': localDate,
        'timeZone': timeZone,
        'throughLocalDate': throughLocalDate,
        'permittedBranchIds': List<String>.of(permittedBranchIds),
        'options': options.map((option) => option.toJson()).toList(),
        if (unavailableReason != null) 'unavailableReason': unavailableReason
      };
}

BookingStatus _status(dynamic value) => switch (value) {
      'pending_hold' => BookingStatus.pendingHold,
      'confirmed' => BookingStatus.confirmed,
      'cancelled' => BookingStatus.cancelled,
      'expired' => BookingStatus.expired,
      'completed' => BookingStatus.completed,
      'refunded' => BookingStatus.refunded,
      _ => invalidBookingData(),
    };
String _rawStatus(BookingStatus value) => switch (value) {
      BookingStatus.pendingHold => 'pending_hold',
      BookingStatus.confirmed => 'confirmed',
      BookingStatus.cancelled => 'cancelled',
      BookingStatus.expired => 'expired',
      BookingStatus.completed => 'completed',
      BookingStatus.refunded => 'refunded',
    };

/// A projection of one persisted document. Elapsed expiry never changes status.
class PersistedBookingRecord {
  PersistedBookingRecord(
      {required this.bookingId,
      required this.organizationId,
      required this.memberId,
      required this.coachId,
      required this.branchId,
      required this.requestId,
      required this.startAtMillis,
      required this.endAtMillis,
      required this.durationMinutes,
      required this.status,
      required this.holdExpiresAtMillis,
      required this.localDate,
      required this.timeZone,
      required this.policyVersion,
      required this.createdAtMillis,
      this.resolvedAtMillis,
      this.resolution,
      required this.startLabel,
      required this.endLabel,
      required this.expiryLabel,
      this.memberDisplayName,
      this.cancellationReason,
      this.cancelledBy,
      this.feeMinor}) {
    if (memberDisplayName != null) bookingText(memberDisplayName, max: 120);
    for (final id in [
      bookingId,
      organizationId,
      memberId,
      coachId,
      branchId,
      requestId
    ]) {
      _bookingIdValue(id);
    }
    bookingInterval(startAtMillis, endAtMillis, durationMinutes);
    bookingInt(holdExpiresAtMillis);
    bookingInt(createdAtMillis);
    if (createdAtMillis > holdExpiresAtMillis ||
        holdExpiresAtMillis > startAtMillis) {
      invalidBookingData();
    }
    bookingDate(localDate);
    bookingTimeZone(timeZone);
    bookingText(policyVersion, max: 128);
    bookingText(startLabel, max: 80);
    bookingText(endLabel, max: 80);
    bookingText(expiryLabel, max: 80);
    if (resolvedAtMillis != null ||
        resolution != null ||
        status == BookingStatus.expired) {
      bookingInt(resolvedAtMillis);
      if (resolvedAtMillis! < createdAtMillis) {
        invalidBookingData();
      }
      if (status == BookingStatus.cancelled) {
        if (resolution == 'member_cancelled') {
          if (resolvedAtMillis! >= holdExpiresAtMillis) invalidBookingData();
        } else if (resolution == 'coach_cancelled') {
          if (resolvedAtMillis! > startAtMillis) invalidBookingData();
        } else if (resolution != null) {
          invalidBookingData();
        }
      } else if (status == BookingStatus.expired) {
        if (resolution != 'hold_expired' ||
            resolvedAtMillis! < holdExpiresAtMillis) {
          invalidBookingData();
        }
      } else {
        invalidBookingData();
      }
    }
    if (cancellationReason != null) {
      bookingText(cancellationReason!, max: 500, multiline: true);
    }
    if (cancelledBy != null) {
      _bookingIdValue(cancelledBy!);
    }
  }
  final String bookingId,
      organizationId,
      memberId,
      coachId,
      branchId,
      requestId;
  final String localDate,
      timeZone,
      policyVersion,
      startLabel,
      endLabel,
      expiryLabel;
  final int startAtMillis,
      endAtMillis,
      durationMinutes,
      holdExpiresAtMillis,
      createdAtMillis;
  final BookingStatus status;
  final int? resolvedAtMillis;
  final String? resolution;
  final String? memberDisplayName;
  final String? cancellationReason;
  final String? cancelledBy;
  final int? feeMinor;
  int get schemaVersion => 1;
  String get rawStatus => _rawStatus(status);
  DateTime get startAt =>
      DateTime.fromMillisecondsSinceEpoch(startAtMillis, isUtc: true);
  DateTime get endAt =>
      DateTime.fromMillisecondsSinceEpoch(endAtMillis, isUtc: true);
  DateTime get holdExpiresAt =>
      DateTime.fromMillisecondsSinceEpoch(holdExpiresAtMillis, isUtc: true);
  factory PersistedBookingRecord.fromJson(Map<String, dynamic> data) {
    bookingShape(data, [
      'bookingId',
      'schemaVersion',
      'organizationId',
      'memberId',
      'coachId',
      'branchId',
      'requestId',
      'startAtMillis',
      'endAtMillis',
      'durationMinutes',
      'status',
      'holdExpiresAtMillis',
      'localDate',
      'timeZone',
      'policyVersion',
      'createdAtMillis',
      'startLabel',
      'endLabel',
      'expiryLabel'
    ], [
      'resolvedAtMillis',
      'resolution',
      'memberDisplayName',
      'cancellationReason',
      'cancelledBy',
      'feeMinor'
    ]);
    if ((data.containsKey('resolvedAtMillis') &&
            data['resolvedAtMillis'] == null) ||
        (data.containsKey('resolution') && data['resolution'] is! String)) {
      invalidBookingData();
    }
    bookingVersion(data['schemaVersion']);
    return PersistedBookingRecord(
        bookingId: _bookingIdValue(data['bookingId']),
        organizationId: _bookingIdValue(data['organizationId']),
        memberId: _bookingIdValue(data['memberId']),
        coachId: _bookingIdValue(data['coachId']),
        branchId: _bookingIdValue(data['branchId']),
        requestId: _bookingIdValue(data['requestId']),
        startAtMillis: bookingInt(data['startAtMillis']),
        endAtMillis: bookingInt(data['endAtMillis']),
        durationMinutes: bookingDuration(data['durationMinutes']),
        status: _status(data['status']),
        holdExpiresAtMillis: bookingInt(data['holdExpiresAtMillis']),
        localDate: bookingDate(data['localDate']),
        timeZone: bookingTimeZone(data['timeZone']),
        policyVersion: bookingText(data['policyVersion'], max: 128),
        createdAtMillis: bookingInt(data['createdAtMillis']),
        resolvedAtMillis: data.containsKey('resolvedAtMillis')
            ? bookingInt(data['resolvedAtMillis'])
            : null,
        resolution: data['resolution'],
        startLabel: bookingText(data['startLabel'], max: 80),
        endLabel: bookingText(data['endLabel'], max: 80),
        expiryLabel: bookingText(data['expiryLabel'], max: 80),
        memberDisplayName: data['memberDisplayName'] == null
            ? null
            : bookingText(data['memberDisplayName'], max: 120),
        cancellationReason: data['cancellationReason'] == null
            ? null
            : bookingText(data['cancellationReason'],
                max: 500, multiline: true),
        cancelledBy: data['cancelledBy'] == null
            ? null
            : _bookingIdValue(data['cancelledBy']),
        feeMinor: data['feeMinor'] == null ? null : bookingInt(data['feeMinor']));
  }
  Map<String, dynamic> toJson() => {
        'bookingId': bookingId,
        'schemaVersion': 1,
        'organizationId': organizationId,
        'memberId': memberId,
        'coachId': coachId,
        'branchId': branchId,
        'requestId': requestId,
        'startAtMillis': startAtMillis,
        'endAtMillis': endAtMillis,
        'durationMinutes': durationMinutes,
        'status': rawStatus,
        'holdExpiresAtMillis': holdExpiresAtMillis,
        'localDate': localDate,
        'timeZone': timeZone,
        'policyVersion': policyVersion,
        'createdAtMillis': createdAtMillis,
        if (resolvedAtMillis != null) 'resolvedAtMillis': resolvedAtMillis,
        if (resolution != null) 'resolution': resolution,
        if (memberDisplayName != null) 'memberDisplayName': memberDisplayName,
        if (cancellationReason != null) 'cancellationReason': cancellationReason,
        if (cancelledBy != null) 'cancelledBy': cancelledBy,
    if (feeMinor != null) 'feeMinor': feeMinor,
        'startLabel': startLabel,
        'endLabel': endLabel,
        'expiryLabel': expiryLabel
      };
}

class BookingCursor {
  BookingCursor({required this.startAtMillis, required this.bookingId}) {
    bookingInt(startAtMillis);
    _bookingIdValue(bookingId);
    if (startAtMillis % bookingSlotMillis != 0) {
      invalidBookingData();
    }
  }
  final int startAtMillis;
  final String bookingId;
  factory BookingCursor.fromJson(Map<String, dynamic> data) {
    bookingShape(data, ['startAtMillis', 'bookingId']);
    return BookingCursor(
        startAtMillis: bookingInt(data['startAtMillis']),
        bookingId: _bookingIdValue(data['bookingId']));
  }
  Map<String, dynamic> toJson() =>
      {'startAtMillis': startAtMillis, 'bookingId': bookingId};
}

class BookingPage {
  BookingPage(
      {required this.serverNowMillis,
      required this.timeZone,
      required this.firstLocalDate,
      required this.throughLocalDate,
      required List<PersistedBookingRecord> records,
      this.nextCursor})
      : records = List.unmodifiable(records) {
    bookingInt(serverNowMillis);
    bookingTimeZone(timeZone);
    bookingDate(firstLocalDate);
    bookingDate(throughLocalDate);
    final days = DateTime.parse('${throughLocalDate}T00:00:00Z')
        .difference(DateTime.parse('${firstLocalDate}T00:00:00Z'))
        .inDays;
    if (days < 0 || days > 30 || records.length > 20) {
      invalidBookingData();
    }
    final ids = <String>{};
    PersistedBookingRecord? previous;
    for (final record in records) {
      if (!ids.add(record.bookingId) ||
          (previous != null &&
              (record.startAtMillis < previous.startAtMillis ||
                  (record.startAtMillis == previous.startAtMillis &&
                      record.bookingId.compareTo(previous.bookingId) <= 0)))) {
        invalidBookingData();
      }
      previous = record;
    }
    if (nextCursor != null &&
        (records.isEmpty ||
            nextCursor!.bookingId != records.last.bookingId ||
            nextCursor!.startAtMillis != records.last.startAtMillis)) {
      invalidBookingData();
    }
  }
  final int serverNowMillis;
  final String timeZone, firstLocalDate, throughLocalDate;
  final List<PersistedBookingRecord> records;
  final BookingCursor? nextCursor;
  int get schemaVersion => 1;
  factory BookingPage.fromJson(Map<String, dynamic> data,
      {String? expectedOrganizationId,
      String? expectedMemberId,
      String? expectedCoachId,
      List<String>? permittedBranchIds,
      String? expectedFirstLocalDate,
      String? expectedThroughLocalDate,
      int? firstStartAtMillis,
      int? throughStartAtMillis}) {
    bookingShape(data, [
      'schemaVersion',
      'serverNowMillis',
      'timeZone',
      'firstLocalDate',
      'throughLocalDate',
      'records'
    ], [
      'nextCursor'
    ]);
    bookingVersion(data['schemaVersion']);
    final records = bookingList(data['records'],
        (raw) => PersistedBookingRecord.fromJson(bookingMap(raw)),
        max: 20);
    for (final record in records) {
      if ((expectedOrganizationId != null &&
              record.organizationId != expectedOrganizationId) ||
          (expectedMemberId != null && record.memberId != expectedMemberId) ||
          (expectedCoachId != null && record.coachId != expectedCoachId) ||
          (permittedBranchIds != null &&
              !permittedBranchIds.contains(record.branchId)) ||
          (firstStartAtMillis != null &&
              record.startAtMillis < firstStartAtMillis) ||
          (throughStartAtMillis != null &&
              record.startAtMillis >= throughStartAtMillis)) {
        invalidBookingData();
      }
    }
    final first = bookingDate(data['firstLocalDate']);
    final through = bookingDate(data['throughLocalDate']);
    if ((expectedFirstLocalDate != null && first != expectedFirstLocalDate) ||
        (expectedThroughLocalDate != null &&
            through != expectedThroughLocalDate)) {
      invalidBookingData();
    }
    return BookingPage(
        serverNowMillis: bookingInt(data['serverNowMillis']),
        timeZone: bookingTimeZone(data['timeZone']),
        firstLocalDate: first,
        throughLocalDate: through,
        records: records,
        nextCursor: data.containsKey('nextCursor')
            ? BookingCursor.fromJson(bookingMap(data['nextCursor']))
            : null);
  }
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'serverNowMillis': serverNowMillis,
        'timeZone': timeZone,
        'firstLocalDate': firstLocalDate,
        'throughLocalDate': throughLocalDate,
        'records': records.map((record) => record.toJson()).toList(),
        if (nextCursor != null) 'nextCursor': nextCursor!.toJson()
      };
}

class BookingException implements Exception {
  const BookingException(this.code);
  final String code;
  String get message => switch (code) {
        'permission-denied' ||
        'unauthenticated' =>
          'Bookings unavailable for this account.',
        'failed-precondition' =>
          'Coach, booking policy or stored records need authorized review.',
        'aborted' ||
        'already-exists' ||
        'resource-exhausted' =>
          'Time availability changed. Refresh options and bookings.',
        'invalid-argument' =>
          'Check the booking date, duration and selected time.',
        'app-check-unavailable' =>
          'Booking attestation unavailable. Retry when ready.',
        _ =>
          'Could not complete the booking operation. Refresh or retry the same request.',
      };
  @override
  String toString() => message;
}

abstract interface class MemberBookingOptionsRepository {
  SessionScope get scope;
  Future<BookingOptionsContext> load(
      {required String coachId,
      String? localDate,
      required int durationMinutes});
}

abstract interface class BookingListRepository {
  SessionScope get scope;
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor});
}

// Keep validators internal to the public booking contract surface.
String _bookingIdValue(dynamic value) => bookingId(value);
