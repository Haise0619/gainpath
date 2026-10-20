import 'package:gainpath_domain/gainpath_domain.dart';

class CreateBookingHoldRequestDto {
  const CreateBookingHoldRequestDto(
      {required this.requestId,
      required this.organizationId,
      required this.memberId,
      required this.branchId,
      required this.coachId,
      required this.startAtMillis,
      required this.durationMinutes});
  factory CreateBookingHoldRequestDto.fromDomain(
          CreateBookingHoldRequest request) =>
      CreateBookingHoldRequestDto(
          requestId: request.requestId,
          organizationId: request.organizationId.value,
          memberId: request.memberId.value,
          branchId: request.branchId.value,
          coachId: request.coachId.value,
          startAtMillis: request.startAt.millisecondsSinceEpoch,
          durationMinutes: request.durationMinutes);
  factory CreateBookingHoldRequestDto.fromJson(Map<String, dynamic> data) =>
      CreateBookingHoldRequestDto.fromDomain(
          CreateBookingHoldRequest.fromJson(data));
  final String requestId, organizationId, memberId, branchId, coachId;
  final int startAtMillis, durationMinutes;
  int get schemaVersion => 1;
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'requestId': requestId,
      'organizationId': organizationId,
      'memberId': memberId,
      'branchId': branchId,
      'coachId': coachId,
      'startAtMillis': startAtMillis,
      'durationMinutes': durationMinutes
    };
    return CreateBookingHoldRequest.fromJson(json).toJson();
  }
}

class BookingHoldDto {
  const BookingHoldDto(
      {required this.bookingId,
      required this.requestId,
      required this.status,
      required this.holdExpiresAt});
  factory BookingHoldDto.fromJson(Map<String, dynamic> data,
      {String? expectedRequestId}) {
    final hold =
        BookingHold.fromJson(data, expectedRequestId: expectedRequestId);
    return BookingHoldDto(
        bookingId: hold.bookingId,
        requestId: hold.requestId,
        status: 'pending_hold',
        holdExpiresAt: hold.holdExpiresAt);
  }
  final String bookingId, requestId, status;
  final DateTime holdExpiresAt;
  int get schemaVersion => 1;
  Map<String, dynamic> toJson() {
    if (holdExpiresAt.microsecondsSinceEpoch % 1000 != 0) {
      throw const FormatException('Unsupported booking response.');
    }
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'requestId': requestId,
      'bookingId': bookingId,
      'status': status,
      'holdExpiresAtMillis': holdExpiresAt.millisecondsSinceEpoch
    };
    return BookingHold.fromJson(json).toJson();
  }

  BookingHold toDomain({String? expectedRequestId}) =>
      BookingHold.fromJson(toJson(), expectedRequestId: expectedRequestId);
}

abstract interface class BookingRemoteDataSource {
  Future<BookingHoldDto> createHold(CreateBookingHoldRequestDto request);
}

class RemoteBookingRepository implements BookingRepository {
  const RemoteBookingRepository(this._source);
  final BookingRemoteDataSource _source;
  @override
  Future<BookingHold> createHold(CreateBookingHoldRequest request) async {
    final dto = await _source
        .createHold(CreateBookingHoldRequestDto.fromDomain(request));
    return dto.toDomain(expectedRequestId: request.requestId);
  }
}
