package com.zyang.gainpath;

/** Main-thread ownership for late initialization, cancellation and callbacks. */
final class AudioPlaybackEpoch {
    private long generation = 0;
    private String utterance;
    private boolean closed;

    boolean begin(long nextGeneration, String id) {
        if (closed || nextGeneration < generation) return false;
        generation = nextGeneration;
        utterance = id;
        return true;
    }

    boolean cancel(long nextGeneration) {
        if (closed || nextGeneration < generation) return false;
        generation = nextGeneration;
        utterance = null;
        return true;
    }

    boolean finish(String id) {
        if (closed || utterance == null || !utterance.equals(id)) return false;
        utterance = null;
        return true;
    }

    long generation() { return generation; }
    void close() { closed = true; utterance = null; }
}
