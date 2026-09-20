import '../entities/availability.dart';

/// Data access contract for the coaching feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class AvailabilityRepository {
  List<WorkingDay> get workingDays;
  List<BlockedSlot> get blockedSlots;
  int get dailyBookingCap;
  set dailyBookingCap(int v);
  int get advanceBookingDays;
  set advanceBookingDays(int v);
}
