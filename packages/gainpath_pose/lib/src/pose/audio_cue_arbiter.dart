enum CuePriority {
  encouragement(1),
  correction(2),
  warning(3);

  const CuePriority(this.weight);
  final int weight;
}

class CueRequest {
  const CueRequest({
    required this.id,
    required this.text,
    required this.priority,
  });

  final String id;
  final String text;
  final CuePriority priority;
}

/// Chooses the most important cue and prevents repetitive spoken feedback.
class AudioCueArbiter {
  AudioCueArbiter({this.cooldownMicros = 2000000});

  final int cooldownMicros;
  final Map<String, CueRequest> _pending = {};
  final Map<String, int> _lastPlayedAt = {};

  void submit(CueRequest request) {
    // Exercise strategies use a small finite cue vocabulary. Bound even a
    // misbehaving producer; duplicate IDs replace text rather than queue speech.
    if (!_pending.containsKey(request.id) && _pending.length >= 32) return;
    _pending[request.id] = request;
  }

  /// Discards old frame requests without resetting the spoken-cue cooldown.
  void clearPending() => _pending.clear();

  CueRequest? takeNext({required int nowMicros}) {
    if (_pending.isEmpty) return null;
    final eligible = _pending.values.where((request) {
      final lastPlayed = _lastPlayedAt[request.id];
      return lastPlayed == null || nowMicros - lastPlayed >= cooldownMicros;
    }).toList()
      ..sort((a, b) => b.priority.weight.compareTo(a.priority.weight));
    if (eligible.isEmpty) return null;
    final request = eligible.first;
    _pending.remove(request.id);
    _lastPlayedAt
        .removeWhere((_, timestamp) => nowMicros - timestamp >= cooldownMicros);
    if (_lastPlayedAt.length >= 128) return null;
    _lastPlayedAt[request.id] = nowMicros;
    // A higher-priority cue makes older lower-priority cues stale.
    _pending.removeWhere(
        (_, queued) => queued.priority.weight < request.priority.weight);
    return request;
  }
}
