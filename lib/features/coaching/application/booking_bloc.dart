import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/features/coaching/domain/entities/booking.dart';
import 'package:gainpath/features/coaching/domain/enums/booking_status.dart';
import 'package:gainpath/features/coaching/domain/repositories/booking_repository.dart';

part 'booking_event.dart';
part 'booking_state.dart';

/// Owns every change to a [Booking] (M7 member side, M9 coach side). Screens
/// dispatch events; nothing outside this Bloc mutates a booking.
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  BookingBloc(this._repo) : super(const BookingState()) {
    on<BookingsRequested>((_, emit) => emit(_snapshot()));
    on<BookingCreated>(_onCreated);
    on<BookingCancelled>(_onCancelled);
    on<BookingRescheduled>(_onRescheduled);
    on<BookingRated>(_onRated);
    on<BookingNotesPublished>(_onNotesPublished);
    on<BookingMessageSent>(_onMessageSent);
  }

  final BookingRepository _repo;

  Booking? _find(String id) {
    for (final b in _repo.allBookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  BookingState _snapshot() {
    final member = _repo.memberBookings;
    List<Booking> byStatus(bool Function(Booking) test, {bool descending = false}) {
      final list = member.where(test).toList()
        ..sort((a, b) => descending ? b.start.compareTo(a.start) : a.start.compareTo(b.start));
      return list;
    }

    return BookingState(
      memberUpcoming: byStatus(
          (b) => b.status == BookingStatus.confirmed || b.status == BookingStatus.pending),
      memberCompleted: byStatus((b) => b.status == BookingStatus.completed, descending: true),
      memberCancelled: byStatus((b) => b.status == BookingStatus.cancelled, descending: true),
      coachRoster: List.unmodifiable(_repo.coachRoster),
      revision: state.revision + 1,
    );
  }

  void _onCreated(BookingCreated e, Emitter<BookingState> emit) {
    _repo.allBookings.add(e.booking);
    emit(_snapshot());
  }

  void _onCancelled(BookingCancelled e, Emitter<BookingState> emit) {
    final b = _find(e.id);
    if (b == null) return;
    b.status = BookingStatus.cancelled;
    b.cancellationReason = e.reason;
    emit(_snapshot());
  }

  void _onRescheduled(BookingRescheduled e, Emitter<BookingState> emit) {
    final b = _find(e.id);
    if (b == null) return;
    b.start = e.newStart;
    emit(_snapshot());
  }

  void _onRated(BookingRated e, Emitter<BookingState> emit) {
    final b = _find(e.id);
    if (b == null) return;
    b.rated = true;
    emit(_snapshot());
  }

  void _onNotesPublished(BookingNotesPublished e, Emitter<BookingState> emit) {
    final b = _find(e.id);
    if (b == null) return;
    b.notes = e.notes;
    b.status = BookingStatus.completed;
    emit(_snapshot());
  }

  void _onMessageSent(BookingMessageSent e, Emitter<BookingState> emit) {
    final b = _find(e.id);
    if (b == null) return;
    b.messages.add(BookingMessage(e.senderRole, e.text, e.sentAt ?? DateTime.now()));
    emit(_snapshot());
  }
}
