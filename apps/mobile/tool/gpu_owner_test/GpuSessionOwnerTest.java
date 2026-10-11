package com.zyang.gainpath;

import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** Host test of the real ownership/queue class, without Android or a GPU. */
public final class GpuSessionOwnerTest {
  public static void main(String[] args) throws Exception {
    AtomicLong thread = new AtomicLong();
    AtomicInteger closed = new AtomicInteger();
    CountDownLatch entered = new CountDownLatch(1), release = new CountDownLatch(1);
    GpuSessionOwner owner = new GpuSessionOwner("test");
    owner.submit(() -> { thread.set(Thread.currentThread().getId()); return 1; }).get();
    CompletableFuture<Integer> active = owner.submit(() -> {
      check(thread.get() == Thread.currentThread().getId());
      entered.countDown(); release.await(); return 2;
    });
    entered.await();
    try { owner.submit(() -> 3).get(); throw new AssertionError("queued frame"); }
    catch (ExecutionException expected) { }
    CompletableFuture<Void> close = owner.close(() -> {
      check(thread.get() == Thread.currentThread().getId()); closed.incrementAndGet();
    });
    check(owner.close(() -> closed.incrementAndGet()) == close);
    release.countDown(); check(active.get() == 2); close.get();
    check(closed.get() == 1);
    try { owner.submit(() -> 4).get(); throw new AssertionError("resurrected"); }
    catch (ExecutionException expected) { }
    GpuSessionOwner failed = new GpuSessionOwner("failed-init");
    try { failed.submit(() -> { throw new IllegalStateException("init"); }).get(); }
    catch (ExecutionException expected) { }
    failed.close(() -> closed.incrementAndGet()).get();
    check(closed.get() == 2);
    System.out.println("GPU owner: single thread, no queued frames, in-flight close, idempotence and failed-init cleanup passed");
  }
  private static void check(boolean condition) { if (!condition) throw new AssertionError(); }
}
