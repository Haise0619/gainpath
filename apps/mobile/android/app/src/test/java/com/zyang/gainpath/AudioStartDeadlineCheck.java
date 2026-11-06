package com.zyang.gainpath;

/** Plain Java deterministic check; run with javac/java, no phone emulation. */
public final class AudioStartDeadlineCheck {
    private static void check(boolean result) {
        if (!result) throw new AssertionError("Native audio deadline/epoch regression");
    }
    public static void main(String[] args) {
        AudioStartDeadline deadline = new AudioStartDeadline();
        deadline.arm(1000, 120L);
        check(!deadline.expired(120999));
        check(deadline.expired(121000));
        check(!deadline.start(121000));
        deadline.arm(1000, 120L);
        check(deadline.start(120999));
        check(!deadline.expired(900000)); // Started speech may finish naturally.
        deadline.arm(1000, 9999L);
        check(deadline.expired(501000)); // Upper bound is enforced natively.
        deadline.arm(1000, null);
        check(deadline.start(999999999)); // Existing exercise policy unchanged.
        AudioPlaybackEpoch epoch = new AudioPlaybackEpoch();
        check(epoch.begin(1, "old"));
        check(epoch.cancel(2));
        check(epoch.begin(2, "new"));
        check(!epoch.isActive("old") && epoch.isActive("new"));
        check(!epoch.finish("old"));
        check(epoch.finish("new"));
        epoch.close();
        check(!epoch.begin(3, "closed"));
        deadline.arm(1150000, 100L, 1100000L);
        check(deadline.expired(1150000)); // Delayed bridge cannot renew expiry.
        check(!deadline.start(1150000));
        deadline.arm(1000000, 500L, 1100000L);
        check(deadline.remainingMillis(1050000) == 50);
        check(deadline.start(1099999));
        System.out.println("18 native deadline/epoch assertions passed");
    }
}
