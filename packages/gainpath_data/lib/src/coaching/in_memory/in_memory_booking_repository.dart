import '../../fakes/mock_data_session.dart';
import 'coaching_seed.dart';
import 'package:gainpath_domain/coaching.dart';

/// Session-scoped in-memory [BookingRepository] backed by [CoachingSeed].
class InMemoryBookingRepository implements BookingRepository {
  InMemoryBookingRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).coaching;

  final CoachingSeed _seed;

  @override
  List<Booking> get allBookings => _seed.allBookings;

  @override
  List<Booking> get memberBookings => _seed.memberBookings;

  @override
  List<Booking> get coachRoster => _seed.coachRoster;
}
