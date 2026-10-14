import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

class BookingCancellationState {
  const BookingCancellationState(
      {this.request, this.busy = false, this.uncertain = false, this.message});
  final CancelBookingHoldRequest? request;
  final bool busy, uncertain;
  final String? message;
}

class BookingCancellationCubit extends Cubit<BookingCancellationState> {
  BookingCancellationCubit(
      {required this.repository,
      required this.isCurrent,
      String Function()? requestId})
      : _requestId = requestId ?? _newId,
        super(const BookingCancellationState());
  final BookingCancellationRepository? repository;
  final bool Function() isCurrent;
  final String Function() _requestId;
  static String _newId() {
    final random = Random.secure();
    return List.generate(
            24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  bool _current() {
    if (isClosed) return false;
    if (isCurrent()) return true;
    emit(const BookingCancellationState(
        message: 'Bookings unavailable for this session.'));
    return false;
  }

  /// True means a trusted terminal response was received; caller must refresh.
  Future<bool> cancel(String bookingId) async {
    if (repository == null ||
        state.busy ||
        !_current() ||
        (state.request != null && state.request!.bookingId != bookingId))
      return false;
    final request = state.request ??
        CancelBookingHoldRequest(
            organizationId: repository!.scope.organizationId,
            bookingId: bookingId,
            requestId: _requestId());
    final uncertain = state.uncertain;
    emit(BookingCancellationState(
        request: request, busy: true, uncertain: uncertain));
    try {
      final result = await repository!.cancelHold(request);
      if (!_current()) return false;
      emit(BookingCancellationState(
          message: result.status == BookingStatus.expired
              ? 'Server marked this hold expired. Refreshing bookings.'
              : 'Server reports this hold cancelled. Refreshing bookings.'));
      return true;
    } catch (error) {
      if (!_current()) return false;
      final code = error is BookingException ? error.code : 'unknown';
      final unknown = uncertain ||
          !{
            'permission-denied',
            'unauthenticated',
            'invalid-argument',
            'failed-precondition',
            'not-found',
            'app-check-unavailable'
          }.contains(code);
      emit(BookingCancellationState(
          request: unknown ? request : null,
          uncertain: unknown,
          message: error is BookingException
              ? error.message
              : const BookingException('unknown').message));
      return false;
    }
  }
}
