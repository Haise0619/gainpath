import 'package:gainpath/features/coaching/domain/entities/booking.dart';

/// Data access contract for the coaching feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class BookingRepository {
  List<Booking> get allBookings;
  List<Booking> get memberBookings;
  List<Booking> get coachRoster;
}
