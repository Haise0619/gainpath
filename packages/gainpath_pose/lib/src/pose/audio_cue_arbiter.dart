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
  final List<CueRequest> _pending = [];
  final Map<String, int> _lastPlayedAt = {};

  void submit(CueRequest request) => _pending.add(request);

  CueRequest? takeNext({required int nowMicros}) {
    if (_pending.isEmpty) return null;
    _pending.sort((a, b) => b.priority.weight.compareTo(a.priority.weight));
    final request = _pending.first;
    final lastPlayed = _lastPlayedAt[request.id];
    if (lastPlayed != null && nowMicros - lastPlayed < cooldownMicros) {
      return null;
    }
    _pending.removeAt(0);
    _lastPlayedAt[request.id] = nowMicros;
    // A higher-priority cue makes older lower-priority cues stale.
    _pending.removeWhere(
        (queued) => queued.priority.weight < request.priority.weight);
    return request;
  }
}
