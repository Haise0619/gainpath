part of 'booking_bloc.dart';

/// Snapshot of bookings for both roles. [Booking] objects are mutable and
/// shared with the repository, so [revision] increments on every change to
/// guarantee the state is seen as new even when the list instances are not.
class BookingState extends Equatable {
  const BookingState({
    this.memberUpcoming = const [],
    this.memberCompleted = const [],
    this.memberCancelled = const [],
    this.coachRoster = const [],
    this.revision = 0,
  });

  final List<Booking> memberUpcoming;
  final List<Booking> memberCompleted;
  final List<Booking> memberCancelled;
  final List<Booking> coachRoster;
  final int revision;

  @override
  List<Object?> get props => [memberUpcoming, memberCompleted, memberCancelled, coachRoster, revision];
}
