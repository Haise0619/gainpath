import 'package:gainpath_domain/gainpath_domain.dart';

class CreateBookingHoldRequestDto {
  const CreateBookingHoldRequestDto({
    required this.requestId,
    required this.organizationId,
    required this.branchId,
    required this.coachId,
    required this.startAtMillis,
    required this.durationMinutes,
  });

  factory CreateBookingHoldRequestDto.fromDomain(
          CreateBookingHoldRequest request) =>
      CreateBookingHoldRequestDto(
        requestId: request.requestId,
        organizationId: request.organizationId.value,
        branchId: request.branchId.value,
        coachId: request.coachId.value,
        startAtMillis: request.startAt.millisecondsSinceEpoch,
        durationMinutes: request.durationMinutes,
      );

  final String requestId;
  final String organizationId;
  final String branchId;
  final String coachId;
  final int startAtMillis;
  final int durationMinutes;
}

class BookingHoldDto {
  const BookingHoldDto({
    required this.bookingId,
    required this.requestId,
    required this.status,
    required this.holdExpiresAt,
  });

  final String bookingId;
  final String requestId;
  final String status;
  final DateTime holdExpiresAt;

  BookingHold toDomain() => BookingHold(
        bookingId: bookingId,
        requestId: requestId,
        status: switch (status) {
          'pending_hold' => BookingStatus.pendingHold,
          'confirmed' => BookingStatus.confirmed,
          'cancelled' => BookingStatus.cancelled,
          'completed' => BookingStatus.completed,
          'refunded' => BookingStatus.refunded,
          _ => throw FormatException('Unknown booking status: $status'),
        },
        holdExpiresAt: holdExpiresAt.toUtc(),
      );
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
    return dto.toDomain();
  }
}
