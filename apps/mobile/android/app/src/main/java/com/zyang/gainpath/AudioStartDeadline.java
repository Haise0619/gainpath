package com.zyang.gainpath;

/** Monotonic native TTS start budget. No frame/render timestamps are used. */
final class AudioStartDeadline {
    private long deadlineMicros;
    private boolean bounded;
    private boolean started;

    void arm(long nowMicros, Long maximumDelayMillis) {
        arm(nowMicros, maximumDelayMillis, null);
    }

    void arm(long nowMicros, Long maximumDelayMillis, Long absoluteExpiryMicros) {
        bounded = maximumDelayMillis != null;
        started = false;
        deadlineMicros = nowMicros + (bounded ? Math.max(0, Math.min(500, maximumDelayMillis)) * 1000 : 0);
        if (absoluteExpiryMicros != null) {
            deadlineMicros = bounded ? Math.min(deadlineMicros, absoluteExpiryMicros) : absoluteExpiryMicros;
            bounded = true;
        }
    }

    long remainingMillis(long nowMicros) {
        return Math.max(0, (deadlineMicros - nowMicros + 999) / 1000);
    }

    boolean expired(long nowMicros) {
        return bounded && !started && nowMicros >= deadlineMicros;
    }

    boolean start(long nowMicros) {
        if (expired(nowMicros)) return false;
        started = true;
        return true;
    }
}
