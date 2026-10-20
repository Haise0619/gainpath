package com.zyang.gainpath;

import java.util.concurrent.Callable;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** All native construction, invocation and destruction belong to this thread.
 * A frame is rejected while another operation is active, never queued. Close is
 * the sole queued operation and runs after any accepted work finishes. */
public final class GpuSessionOwner {
    private final ExecutorService executor;
    private boolean busy, closing;
    private CompletableFuture<Void> closed;

    public GpuSessionOwner(String id) {
        executor = Executors.newSingleThreadExecutor(r -> new Thread(r, "pose-gpu-" + id));
    }

    public synchronized <T> CompletableFuture<T> submit(Callable<T> action) {
        CompletableFuture<T> result = new CompletableFuture<>();
        if (closing || busy) {
            result.completeExceptionally(new IllegalStateException(closing ? "GPU session closing" : "GPU operation active"));
            return result;
        }
        busy = true;
        executor.execute(() -> {
            T value = null; Throwable failure = null;
            try { value = action.call(); } catch (Throwable e) { failure = e; }
            synchronized (this) { busy = false; }
            if (failure == null) result.complete(value); else result.completeExceptionally(failure);
        });
        return result;
    }

    public synchronized CompletableFuture<Void> close(Runnable dispose) {
        if (closed != null) return closed;
        closing = true;
        closed = new CompletableFuture<>();
        executor.execute(() -> {
            try { dispose.run(); closed.complete(null); }
            catch (Throwable e) { closed.completeExceptionally(e); }
            finally { executor.shutdown(); }
        });
        return closed;
    }
}
