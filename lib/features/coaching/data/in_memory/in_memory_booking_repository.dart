import 'package:gainpath/features/coaching/data/in_memory/coaching_seed.dart';
import 'package:gainpath/features/coaching/domain/entities/booking.dart';
import 'package:gainpath/features/coaching/domain/repositories/booking_repository.dart';

/// Session-scoped in-memory [BookingRepository] backed by [CoachingSeed].
class InMemoryBookingRepository implements BookingRepository {
  @override
  List<Booking> get allBookings => CoachingSeed.allBookings;

  @override
  List<Booking> get memberBookings => CoachingSeed.memberBookings;

  @override
  List<Booking> get coachRoster => CoachingSeed.coachRoster;
}
