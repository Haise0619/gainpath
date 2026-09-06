import 'package:gainpath/features/coaching/data/in_memory/coaching_seed.dart';
import 'package:gainpath/features/coaching/domain/entities/availability.dart';
import 'package:gainpath/features/coaching/domain/repositories/availability_repository.dart';

/// Session-scoped in-memory [AvailabilityRepository] backed by [CoachingSeed].
class InMemoryAvailabilityRepository implements AvailabilityRepository {
  @override
  List<WorkingDay> get workingDays => CoachingSeed.workingDays;

  @override
  List<BlockedSlot> get blockedSlots => CoachingSeed.blockedSlots;

  @override
  int get dailyBookingCap => CoachingSeed.dailyBookingCap;

  @override
  set dailyBookingCap(int v) => CoachingSeed.dailyBookingCap = v;

  @override
  int get advanceBookingDays => CoachingSeed.advanceBookingDays;

  @override
  set advanceBookingDays(int v) => CoachingSeed.advanceBookingDays = v;
}
