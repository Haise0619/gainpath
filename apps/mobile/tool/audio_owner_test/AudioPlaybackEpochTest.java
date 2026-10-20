package com.zyang.gainpath;

public final class AudioPlaybackEpochTest {
  private static void check(boolean condition, String message) {
    if (!condition) throw new AssertionError(message);
  }
  public static void main(String[] args) {
    AudioPlaybackEpoch epoch = new AudioPlaybackEpoch();
    check(epoch.begin(0, "first"), "initial playback");
    check(epoch.cancel(1), "pause invalidates previous generation");
    check(!epoch.begin(0, "late-init"), "late initialization cannot speak");
    check(epoch.begin(1, "warning"), "new warning accepted");
    check(!epoch.finish("first"), "old completion cannot finish warning");
    check(!epoch.cancel(0), "old stop cannot swallow new warning");
    check(epoch.finish("warning"), "matching completion");
    check(!epoch.finish("warning"), "completion once only");
    check(epoch.begin(1, "next"), "fresh utterance");
    epoch.close();
    check(!epoch.begin(2, "after-logout"), "closed epoch cannot resurrect");
    check(!epoch.finish("next"), "late done after close ignored");
    System.out.println("AudioPlaybackEpoch: 11 checks passed");
  }
}
