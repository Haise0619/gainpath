import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OS network availability only; it does not assert server reachability.
Stream<void> workoutBackupNetworkOpportunities() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const Stream<void>.empty();
  }
  return _androidOpportunities;
}

final _androidOpportunities =
    const EventChannel('gainpath/network_opportunities')
        .receiveBroadcastStream()
        .map<void>((_) {});
