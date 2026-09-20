part of 'booking_bloc.dart';

sealed class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

/// Load (or reload) the member's bookings and the coach roster.
class BookingsRequested extends BookingEvent {
  const BookingsRequested();
}

/// A paid session was booked (SD-M7.2).
class BookingCreated extends BookingEvent {
  const BookingCreated(this.booking);
  final Booking booking;
  @override
  List<Object?> get props => [booking];
}

/// Member or coach cancelled a session (SD-M7.3).
class BookingCancelled extends BookingEvent {
  const BookingCancelled(this.id, this.reason);
  final String id;
  final String reason;
  @override
  List<Object?> get props => [id, reason];
}

/// Member moved a session to a new slot (SD-M7.3).
class BookingRescheduled extends BookingEvent {
  const BookingRescheduled(this.id, this.newStart);
  final String id;
  final DateTime newStart;
  @override
  List<Object?> get props => [id, newStart];
}

/// Member rated a completed session (SD-M7.3).
class BookingRated extends BookingEvent {
  const BookingRated(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// Coach published post-workout consultation notes, completing the session (SD-M9.2).
class BookingNotesPublished extends BookingEvent {
  const BookingNotesPublished(this.id, this.notes);
  final String id;
  final String notes;
  @override
  List<Object?> get props => [id, notes];
}

/// A message was added to the booking's member-coach thread.
class BookingMessageSent extends BookingEvent {
  const BookingMessageSent(this.id, {required this.senderRole, required this.text, this.sentAt});
  final String id;
  final String senderRole;
  final String text;
  final DateTime? sentAt;
  @override
  List<Object?> get props => [id, senderRole, text, sentAt];
}
