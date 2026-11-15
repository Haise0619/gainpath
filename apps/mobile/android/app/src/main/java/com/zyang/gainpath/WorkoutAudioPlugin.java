package com.zyang.gainpath;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.content.res.AssetFileDescriptor;
import java.io.InputStream;
import java.io.IOException;
import org.json.JSONObject;
import org.json.JSONArray;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.speech.tts.Voice;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Session-scoped recorded coach and offline TTS fallback. No camera/network/persistence. */
public final class WorkoutAudioPlugin implements FlutterPlugin,
        MethodChannel.MethodCallHandler, ActivityAware {
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<String, SpeechSession> sessions = new HashMap<>();
    private Context context;
    private MethodChannel channel;
    private io.flutter.plugin.common.BinaryMessenger messenger;
    private Activity activity;
    private Application application;
    private boolean foreground;
    private FlutterPlugin.FlutterAssets flutterAssets;
    private SpeechSession activeOwner;

    private final Application.ActivityLifecycleCallbacks lifecycle =
        new Application.ActivityLifecycleCallbacks() {
            public void onActivityResumed(Activity value) {
                if (value == activity) foreground = true;
            }
            public void onActivityPaused(Activity value) {
                if (value == activity) suspend();
            }
            public void onActivityStopped(Activity value) {
                if (value == activity) suspend();
            }
            public void onActivityCreated(Activity value, Bundle state) {}
            public void onActivityStarted(Activity value) {}
            public void onActivitySaveInstanceState(Activity value, Bundle state) {}
            public void onActivityDestroyed(Activity value) {}
        };

    @Override public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        messenger = binding.getBinaryMessenger();
        flutterAssets = binding.getFlutterAssets();
        channel = new MethodChannel(binding.getBinaryMessenger(), "gainpath/workout_audio");
        channel.setMethodCallHandler(this);
    }

    @Override public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        detachActivity();
        for (SpeechSession session : sessions.values()) session.close();
        sessions.clear();
        channel.setMethodCallHandler(null);
        channel = null;
        context = null;
        messenger = null;
    }

    @Override public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        application = activity.getApplication();
        application.registerActivityLifecycleCallbacks(lifecycle);
        foreground = true;
    }
    @Override public void onDetachedFromActivityForConfigChanges() { detachActivity(); }
    @Override public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding b) {
        onAttachedToActivity(b);
    }
    @Override public void onDetachedFromActivity() { detachActivity(); }

    private void detachActivity() {
        suspend();
        if (application != null) application.unregisterActivityLifecycleCallbacks(lifecycle);
        activity = null;
        application = null;
    }
    private void suspend() {
        foreground = false;
        for (SpeechSession session : sessions.values()) session.stop(session.epoch.generation());
    }

    @Override public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        String id = call.argument("sessionId");
        Number generation = call.argument("generation");
        if (id == null || id.isEmpty() || id.length() > 128 || generation == null) {
            result.error("invalid_audio_request", "Session and generation required", null);
            return;
        }
        SpeechSession session = sessions.get(id);
        switch (call.method) {
            case "create":
                if (session != null || sessions.size() >= 4 || !foreground) {
                    result.success(false);
                    return;
                }
                session = new SpeechSession(id, result,
                    Boolean.TRUE.equals(call.argument("trace")),
                    Boolean.TRUE.equals(call.argument("coachAssets")));
                sessions.put(id, session);
                session.initialize();
                return;
            case "play":
                if (session == null) { result.success("unavailable"); return; }
                Number delay = call.argument("maxStartDelayMs");
                Number deadline = call.argument("startDeadlineMicros");
                session.play(generation.longValue(), call.argument("text"),
                    call.argument("cueId"), call.argument("requestId"),
                    call.argument("asset"),
                    delay == null ? null : delay.longValue(),
                    deadline == null ? null : deadline.longValue(), result);
                return;
            case "clock":
                result.success(session == null || !foreground ? null :
                    SystemClock.elapsedRealtimeNanos() / 1000);
                return;
            case "stop":
                if (session != null) session.stop(generation.longValue());
                result.success(null);
                return;
            case "close":
                if (session != null) { session.close(); sessions.remove(id); }
                result.success(null);
                return;
            default: result.notImplemented();
        }
    }

    private final class SpeechSession {
        final String id;
        final AudioPlaybackEpoch epoch = new AudioPlaybackEpoch();
        final AudioManager audioManager;
        final AudioAttributes attributes = new AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build();
        final AudioFocusRequest focus;
        TextToSpeech tts;
        MediaPlayer player;
        boolean ttsReady, initializingTts;
        Runnable afterTtsReady;
        final boolean coachAssets;
        final Map<String, String> assets = new HashMap<>();
        MethodChannel.Result readyResult;
        MethodChannel.Result playbackResult;
        boolean ready;
        boolean closed;
        long sequence;
        Runnable initializationTimeout;
        Runnable playbackTimeout;
        Runnable startTimeout;
        final AudioStartDeadline startDeadline = new AudioStartDeadline();
        final MethodChannel traceChannel;
        String requestId;
        String cueId;

        SpeechSession(String id, MethodChannel.Result result, boolean trace, boolean coachAssets) {
            this.id = id;
            this.coachAssets = coachAssets;
            readyResult = result;
            traceChannel = trace ? new MethodChannel(messenger,
                "gainpath/workout_audio/events/" + id) : null;
            audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(change -> {
                    if (change < 0) stop(epoch.generation());
                }, main).build();
        }

        void initialize() {
            if (coachAssets) {
                try (InputStream input = context.getAssets().open(flutterAssets.getAssetFilePathByName(
                        "assets/audio/coach_en/default_v1/manifest.json"))) {
                    java.io.ByteArrayOutputStream bytes = new java.io.ByteArrayOutputStream();
                    byte[] buffer = new byte[4096]; int count;
                    while ((count = input.read(buffer)) != -1) bytes.write(buffer, 0, count);
                    JSONArray clips = new JSONObject(bytes.toString("UTF-8")).getJSONArray("clips");
                    for (int i = 0; i < clips.length(); i++) {
                        JSONObject clip = clips.getJSONObject(i);
                        String file = clip.getString("file");
                        if (!file.contains("..") && !file.startsWith("/")) {
                            assets.put(clip.getString("id"), "assets/audio/coach_en/default_v1/" + file);
                        }
                    }
                    if (!assets.isEmpty()) {
                        completeReady(true);
                        // Do not gate assets on TTS. Warm the offline fallback
                        // silently in this enabled session so31 need not wait
                        // for a cold engine; it never acquires focus or speaks.
                        initializeTts();
                        return;
                    }
                } catch (Exception ignored) { /* Offline TTS fallback. */ }
            }
            initializeTts();
        }

        void initializeTts() {
            if (initializingTts || closed) return;
            initializingTts = true;
            initializationTimeout = () -> { finishTts(false); shutdownEngine(); };
            main.postDelayed(initializationTimeout, 10000);
            try {
                tts = new TextToSpeech(context, status -> main.post(() -> onInit(status)));
            } catch (RuntimeException error) {
                finishTts(false);
                shutdownEngine();
            }
        }

        void onInit(int status) {
            if (closed || !initializingTts) return;
            try {
                if (status != TextToSpeech.SUCCESS || tts == null) {
                    finishTts(false); shutdownEngine(); return;
                }
                Set<Voice> voices = tts.getVoices();
                List<Voice> offline = new ArrayList<>();
                if (voices != null) for (Voice voice : voices) {
                    if (!voice.isNetworkConnectionRequired() &&
                            (voice.getFeatures() == null || !voice.getFeatures().contains(
                                TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)) &&
                            Locale.ENGLISH.getLanguage().equals(voice.getLocale().getLanguage())) {
                        offline.add(voice);
                    }
                }
                offline.sort(Comparator.comparing((Voice voice) ->
                    !Locale.US.equals(voice.getLocale())).thenComparing(Voice::getName));
                boolean voiceSelected = false;
                for (Voice voice : offline) {
                    if (tts.setVoice(voice) == TextToSpeech.SUCCESS) {
                        voiceSelected = true;
                        break;
                    }
                }
                if (!voiceSelected) {
                    finishTts(false); shutdownEngine(); return;
                }
                tts.setAudioAttributes(attributes);
                tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                    @Override public void onStart(String utteranceId) {
                        // Timestamp on the engine callback thread, not after a
                        // potentially delayed main-thread dispatch.
                        long startedAt = SystemClock.elapsedRealtimeNanos() / 1000;
                        main.post(() -> {
                            if (!epoch.isActive(utteranceId)) return;
                            if (!startDeadline.start(startedAt)) {
                                trace("expired_before_start", startedAt);
                                stop(epoch.generation());
                                return;
                            }
                            if (startTimeout != null) main.removeCallbacks(startTimeout);
                            trace("playback_start", startedAt);
                        });
                    }
                    @Override public void onDone(String utteranceId) {
                        long at = SystemClock.elapsedRealtimeNanos() / 1000;
                        main.post(() -> completePlayback(utteranceId, "completed", at));
                    }
                    @Override public void onError(String utteranceId) {
                        long at = SystemClock.elapsedRealtimeNanos() / 1000;
                        main.post(() -> completePlayback(utteranceId, "unavailable", at));
                    }
                    @Override public void onError(String utteranceId, int code) { onError(utteranceId); }
                    @Override public void onStop(String utteranceId, boolean interrupted) {
                        long at = SystemClock.elapsedRealtimeNanos() / 1000;
                        main.post(() -> completePlayback(utteranceId, "cancelled", at));
                    }
                });
                finishTts(true);
            } catch (RuntimeException error) {
                finishTts(false); shutdownEngine();
            }
        }

        void finishTts(boolean available) {
            initializingTts = false;
            ttsReady = available && !closed;
            if (initializationTimeout != null) main.removeCallbacks(initializationTimeout);
            if (readyResult != null) completeReady(available);
            Runnable pending = afterTtsReady;
            afterTtsReady = null;
            if (pending != null) pending.run();
        }

        void completeReady(boolean available) {
            if (initializationTimeout != null) main.removeCallbacks(initializationTimeout);
            ready = available && !closed;
            if (readyResult != null) {
                MethodChannel.Result result = readyResult;
                readyResult = null;
                result.success(ready);
            }
        }

        void play(long generation, String text, String nextCueId, String nextRequestId,
                  String asset,
                  Long maximumStartDelayMillis, Long absoluteExpiryMicros, MethodChannel.Result result) {
            if (closed || !foreground || !ready || text == null ||
                    text.trim().isEmpty() || text.length() > 240) {
                result.success("unavailable"); return;
            }
            if (!epoch.cancel(generation)) { result.success("cancelled"); return; }
            cancelPlayback();
            if (activeOwner != null && activeOwner != this) activeOwner.stop(activeOwner.epoch.generation());
            activeOwner = this;
            requestId = nextRequestId;
            cueId = nextCueId;
            String utteranceId = id + ":" + (++sequence);
            if (!epoch.begin(generation, utteranceId)) { result.success("cancelled"); return; }
            playbackResult = result;
            long receivedAt = SystemClock.elapsedRealtimeNanos() / 1000;
            startDeadline.arm(receivedAt, maximumStartDelayMillis, absoluteExpiryMicros);
            if (startDeadline.expired(receivedAt)) {
                trace("expired_before_start", receivedAt);
                stop(epoch.generation());
                return;
            }
            if (maximumStartDelayMillis != null) {
                startTimeout = () -> {
                    if (epoch.isActive(utteranceId) && startDeadline.expired(
                            SystemClock.elapsedRealtimeNanos() / 1000)) {
                        trace("expired_before_start", SystemClock.elapsedRealtimeNanos() / 1000);
                        stop(epoch.generation());
                    }
                };
                main.postDelayed(startTimeout, startDeadline.remainingMillis(receivedAt));
            }
            playbackTimeout = () -> {
                completePlayback(utteranceId, "unavailable");
                releasePlayer();
                if (tts != null) tts.stop();
            };
            main.postDelayed(playbackTimeout, 20000);
            try {
                if (audioManager == null || audioManager.requestAudioFocus(focus) !=
                        AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                    completePlayback(utteranceId, "unavailable");
                    return;
                }
                if (asset != null && asset.equals(assets.get(nextCueId))) playAsset(asset, text, utteranceId);
                else playTts(text, utteranceId);
            } catch (RuntimeException error) {
                completePlayback(utteranceId, "unavailable");
            }
        }

        void playAsset(String asset, String fallback, String utteranceId) {
            try (AssetFileDescriptor file = context.getAssets().openFd(
                    flutterAssets.getAssetFilePathByName(asset))) {
                final MediaPlayer media = new MediaPlayer();
                player = media;
                media.setAudioAttributes(attributes);
                media.setDataSource(file.getFileDescriptor(), file.getStartOffset(), file.getLength());
                media.setOnPreparedListener(value -> {
                    if (!epoch.isActive(utteranceId) || player != value) return;
                    long at = SystemClock.elapsedRealtimeNanos() / 1000;
                    if (!foreground || !startDeadline.start(at)) { stop(epoch.generation()); return; }
                    if (startTimeout != null) main.removeCallbacks(startTimeout);
                    try { value.start(); trace("playback_start", at); }
                    catch (RuntimeException error) { completePlayback(utteranceId, "unavailable"); }
                });
                media.setOnCompletionListener(value -> completePlayback(utteranceId, "completed"));
                media.setOnErrorListener((value, what, extra) -> {
                    if (epoch.isActive(utteranceId) && player == value) {
                        releasePlayer();
                        if (startDeadline.canFallback(SystemClock.elapsedRealtimeNanos() / 1000)) {
                            playTts(fallback, utteranceId);
                        } else { completePlayback(utteranceId, "unavailable"); }
                    }
                    return true;
                });
                trace("native_asset_request", SystemClock.elapsedRealtimeNanos() / 1000);
                media.prepareAsync();
            } catch (IOException | RuntimeException error) {
                releasePlayer(); playTts(fallback, utteranceId);
            }
        }

        void playTts(String text, String utteranceId) {
            if (!epoch.isActive(utteranceId) || closed) return;
            if (startDeadline.expired(SystemClock.elapsedRealtimeNanos() / 1000)) {
                stop(epoch.generation()); return;
            }
            if (!ttsReady) {
                if (initializingTts) { afterTtsReady = () -> playTts(text, utteranceId); return; }
                if (tts != null) { completePlayback(utteranceId, "unavailable"); return; }
                afterTtsReady = () -> {
                    if (ttsReady) playTts(text, utteranceId);
                    else completePlayback(utteranceId, "unavailable");
                };
                initializeTts();
                return;
            }
            try {
                trace("native_tts_request", SystemClock.elapsedRealtimeNanos() / 1000);
                if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId) != TextToSpeech.SUCCESS) {
                    completePlayback(utteranceId, "unavailable");
                }
            } catch (RuntimeException error) { completePlayback(utteranceId, "unavailable"); }
        }

        void releasePlayer() {
            if (player == null) return;
            MediaPlayer old = player; player = null;
            old.setOnPreparedListener(null); old.setOnCompletionListener(null); old.setOnErrorListener(null);
            try { old.release(); } catch (RuntimeException ignored) {}
        }

        void completePlayback(String utteranceId, String outcome) {
            completePlayback(utteranceId, outcome, SystemClock.elapsedRealtimeNanos() / 1000);
        }
        void completePlayback(String utteranceId, String outcome, long atMicros) {
            if (!epoch.finish(utteranceId)) return;
            resolvePlayback(outcome, atMicros);
        }
        void resolvePlayback(String outcome) {
            resolvePlayback(outcome, SystemClock.elapsedRealtimeNanos() / 1000);
        }
        void resolvePlayback(String outcome, long atMicros) {
            releasePlayer();
            afterTtsReady = null;
            if (activeOwner == this) activeOwner = null;
            if (playbackResult != null) trace("playback_" + outcome, atMicros);
            if (startTimeout != null) main.removeCallbacks(startTimeout);
            startTimeout = null;
            if (playbackTimeout != null) main.removeCallbacks(playbackTimeout);
            playbackTimeout = null;
            if (audioManager != null) audioManager.abandonAudioFocusRequest(focus);
            if (playbackResult != null) {
                MethodChannel.Result result = playbackResult;
                playbackResult = null;
                result.success(outcome);
            }
        }
        void trace(String stage, long atMicros) {
            if (traceChannel == null || requestId == null) return;
            Map<String, Object> row = new HashMap<>();
            row.put("stage", stage);
            row.put("requestId", requestId);
            row.put("cueId", cueId);
            row.put("generation", epoch.generation());
            row.put("nativeElapsedMicros", atMicros);
            traceChannel.invokeMethod("trace", row);
        }
        void cancelPlayback() {
            // Platform engine failure must not leave pending futures or focus.
            if (tts != null) {
                try { tts.stop(); } catch (RuntimeException ignored) {}
            }
            resolvePlayback("cancelled");
        }
        void stop(long generation) {
            if (epoch.cancel(generation)) cancelPlayback();
        }
        void shutdownEngine() {
            ttsReady = false;
            initializingTts = false;
            if (tts != null) {
                try { tts.shutdown(); } catch (RuntimeException ignored) {}
                tts = null;
            }
            if (assets.isEmpty()) ready = false;
        }
        void close() {
            if (closed) return;
            stop(epoch.generation());
            closed = true;
            epoch.close();
            completeReady(false);
            shutdownEngine();
        }
    }
}
