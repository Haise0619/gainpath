import 'package:flutter/foundation.dart';
import 'real_workout_contract.dart';
import 'real_workout_sync.dart';

/// Upload state and actions displayed alongside a saved measured result.
abstract interface class RealWorkoutSyncPresentation implements Listenable {
  List<RealWorkoutSyncEntry> get entries;
  WorkoutConsentAcknowledgement? get consent;
  bool get revocationPending;
  bool get syncing;
  Future<void> sync();
  Future<void> revokeConsent();
}
