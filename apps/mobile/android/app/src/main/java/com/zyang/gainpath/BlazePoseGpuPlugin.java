package com.zyang.gainpath;

import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import java.io.File;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.tensorflow.lite.Interpreter;
import org.tensorflow.lite.Tensor;
import org.tensorflow.lite.gpu.GpuDelegate;
import org.tensorflow.lite.gpu.GpuDelegateFactory;

/** Native acceleration transport. No camera, preprocessing, filtering or workout APIs.
 * OpenCL is required here; Dart may select a separate validated CPU interpreter
 * after initialization failure. This transport never relabels CPU/GL as OpenCL. */
public final class BlazePoseGpuPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<String, Session> sessions = new HashMap<>();
    private boolean attached;

    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        attached = true;
        channel = new MethodChannel(binding.getBinaryMessenger(), "gainpath/blazepose_gpu");
        channel.setMethodCallHandler(this);
    }
    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        attached = false;
        channel.setMethodCallHandler(null);
        for (Session session : sessions.values()) session.close();
        sessions.clear();
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("session");
        try {
            if (!attached || id == null) throw new IllegalStateException("GPU channel detached or missing session");
            if (call.method.equals("create")) {
                if (sessions.containsKey(id)) throw new IllegalStateException("Duplicate GPU session");
                Session session = new Session(id);
                sessions.put(id, session);
                List<String> paths = call.argument("paths");
                reply(session.owner.submit(() -> session.create(paths)), result, session, true);
            } else if (call.method.equals("close")) {
                Session session = sessions.get(id);
                if (session == null) result.success(null);
                else reply(closeSession(session), result, session, false);
            } else if (call.method.equals("invoke")) {
                Session session = sessions.get(id);
                if (session == null) throw new IllegalStateException("Unknown GPU session");
                Integer model = call.argument("model"); byte[] input = call.argument("input");
                reply(session.owner.submit(() -> session.invoke(model, input)), result, session, false);
            } else result.notImplemented();
        } catch (Throwable e) { result.error("gpu", e.toString(), null); }
    }
    private void reply(CompletableFuture<?> future, MethodChannel.Result result, Session session, boolean initializing) {
        future.whenComplete((value, error) -> main.post(() -> {
            if (error != null) {
                Log.e("GainPathGPU", "failed session="+session.id, error);
                closeSession(session);
                result.error("gpu", error.toString(), null);
            } else if (initializing && (!attached || session.closing || sessions.get(session.id) != session)) {
                closeSession(session); result.error("gpu", "GPU creation canceled", null);
            } else result.success(value);
        }));
    }
    private CompletableFuture<Void> closeSession(Session session) {
        CompletableFuture<Void> closed = session.close();
        closed.whenComplete((v, e) -> main.post(() -> sessions.remove(session.id, session)));
        return closed;
    }
    private static final class Session {
        final String id;
        final GpuSessionOwner owner;
        final Interpreter[] models = new Interpreter[2];
        final GpuDelegate[] delegates = new GpuDelegate[2];
        final ByteBuffer[] inputs = new ByteBuffer[2];
        final Map<Integer, Object>[] outputs;
        long thread;
        volatile boolean closing;
        @SuppressWarnings("unchecked") Session(String id) {
            this.id = id; owner = new GpuSessionOwner(id);
            outputs = (Map<Integer, Object>[]) new Map<?, ?>[2];
        }
        Object create(List<String> paths) {
            if (paths == null || paths.size() != 2) throw new IllegalArgumentException("Two verified model paths required");
            thread = android.os.Process.myTid();
            long start = SystemClock.elapsedRealtimeNanos();
            List<Object> inventory = new ArrayList<>();
            for (int m = 0; m < 2; m++) {
                GpuDelegateFactory.Options gpu = new GpuDelegateFactory.Options()
                    .setPrecisionLossAllowed(false)
                    .setForceBackend(GpuDelegateFactory.Options.GpuBackend.OPENCL);
                delegates[m] = new GpuDelegate(gpu);
                // Keep the control's two CPU threads for any residual operations.
                // XNNPACK is disabled to match the existing C-API CPU options.
                models[m] = new Interpreter(new File(paths.get(m)), new Interpreter.Options()
                    .setNumThreads(2).setUseXNNPACK(false).addDelegate(delegates[m]));
                models[m].allocateTensors();
                List<Object> in = new ArrayList<>(), out = new ArrayList<>();
                for (int n = 0; n < models[m].getInputTensorCount(); n++) in.add(spec(models[m].getInputTensor(n)));
                for (int n = 0; n < models[m].getOutputTensorCount(); n++) out.add(spec(models[m].getOutputTensor(n)));
                Map<String,Object> contract = new HashMap<>(); contract.put("inputs", in); contract.put("outputs", out);
                inventory.add(contract);
                inputs[m] = buffer(models[m].getInputTensor(0).numBytes());
                outputs[m] = new LinkedHashMap<>();
                for (int n : (m == 0 ? new int[]{0,1} : new int[]{0,1,3,4}))
                    outputs[m].put(n, buffer(models[m].getOutputTensor(n).numBytes()));
            }
            Map<String,Object> info = new HashMap<>();
            info.put("models", inventory); info.put("ownerThread", thread);
            info.put("backend", "opencl_required");
            info.put("initializationMicros", (SystemClock.elapsedRealtimeNanos()-start)/1000);
            Log.i("GainPathGPU", "created session="+id+" owner="+thread+" backend=opencl_required");
            return info;
        }
        Object invoke(Integer model, byte[] data) {
            if (android.os.Process.myTid() != thread) throw new IllegalStateException("GPU owner changed");
            if (model == null || model < 0 || model > 1 || data == null || data.length != inputs[model].capacity())
                throw new IllegalArgumentException("GPU input contract mismatch");
            long start = SystemClock.elapsedRealtimeNanos();
            inputs[model].clear(); inputs[model].put(data); inputs[model].rewind();
            for (Object output : outputs[model].values()) ((ByteBuffer)output).clear();
            models[model].runForMultipleInputsOutputs(new Object[]{inputs[model]}, outputs[model]);
            Long nativeDuration = models[model].getLastNativeInferenceDurationNanoseconds();
            if (nativeDuration == null) throw new IllegalStateException("Missing native inference duration");
            long elapsed = nativeDuration;
            List<byte[]> resultOutputs = new ArrayList<>();
            for (Object output : outputs[model].values()) {
                ByteBuffer b = (ByteBuffer) output; b.rewind();
                byte[] bytes = new byte[b.capacity()]; b.get(bytes); resultOutputs.add(bytes);
            }
            Map<String,Object> result = new HashMap<>(); result.put("outputs", resultOutputs);
            result.put("ownerThread", thread); result.put("nativeMicros", elapsed/1000);
            result.put("copyMicros", (SystemClock.elapsedRealtimeNanos()-start-elapsed)/1000);
            return result;
        }
        CompletableFuture<Void> close() { closing = true; return owner.close(() -> {
            if (thread != 0 && android.os.Process.myTid() != thread) throw new IllegalStateException("GPU dispose owner changed");
            // Every resource is attempted even if one close fails.
            Throwable failure = null;
            for (int m = 1; m >= 0; m--) {
                try { if (models[m] != null) models[m].close(); } catch (Throwable e) { failure = e; }
                try { if (delegates[m] != null) delegates[m].close(); } catch (Throwable e) { failure = e; }
                models[m] = null; delegates[m] = null; inputs[m] = null; outputs[m] = null;
            }
            Log.i("GainPathGPU", "closed session="+id+" owner="+android.os.Process.myTid());
            if (failure != null) throw new IllegalStateException("GPU cleanup failed", failure);
        }); }
        static ByteBuffer buffer(int bytes) { return ByteBuffer.allocateDirect(bytes).order(ByteOrder.nativeOrder()); }
        static Map<String,Object> spec(Tensor tensor) {
            Map<String,Object> s = new HashMap<>(); s.put("name", tensor.name());
            List<Integer> shape = new ArrayList<>(); for (int n : tensor.shape()) shape.add(n);
            s.put("shape", shape); s.put("type", tensor.dataType().toString().toLowerCase(Locale.ROOT)); return s;
        }
    }
}
