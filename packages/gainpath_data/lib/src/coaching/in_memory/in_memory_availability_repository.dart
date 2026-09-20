import '../../fakes/mock_data_session.dart';
import 'coaching_seed.dart';
import 'package:gainpath_domain/coaching.dart';

/// Session-scoped in-memory [AvailabilityRepository] backed by [CoachingSeed].
class InMemoryAvailabilityRepository implements AvailabilityRepository {
  InMemoryAvailabilityRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).coaching;

  final CoachingSeed _seed;

  @override
  List<WorkingDay> get workingDays => _seed.workingDays;

  @override
  List<BlockedSlot> get blockedSlots => _seed.blockedSlots;

  @override
  int get dailyBookingCap => _seed.dailyBookingCap;

  @override
  set dailyBookingCap(int v) => _seed.dailyBookingCap = v;

  @override
  int get advanceBookingDays => _seed.advanceBookingDays;

  @override
  set advanceBookingDays(int v) => _seed.advanceBookingDays = v;
}
