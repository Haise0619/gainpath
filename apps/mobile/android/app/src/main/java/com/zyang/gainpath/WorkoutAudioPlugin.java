package com.zyang.gainpath;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
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

/** Session-scoped offline TTS. No camera, analytics, network or persistence. */
public final class WorkoutAudioPlugin implements FlutterPlugin,
        MethodChannel.MethodCallHandler, ActivityAware {
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Map<String, SpeechSession> sessions = new HashMap<>();
    private Context context;
    private MethodChannel channel;
    private Activity activity;
    private Application application;
    private boolean foreground;

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
                session = new SpeechSession(id, result);
                sessions.put(id, session);
                session.initialize();
                return;
            case "play":
                if (session == null) { result.success("unavailable"); return; }
                session.play(generation.longValue(), call.argument("text"), result);
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
        MethodChannel.Result readyResult;
        MethodChannel.Result playbackResult;
        boolean ready;
        boolean closed;
        long sequence;
        Runnable initializationTimeout;
        Runnable playbackTimeout;

        SpeechSession(String id, MethodChannel.Result result) {
            this.id = id;
            readyResult = result;
            audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
            focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(change -> {
                    if (change < 0) stop(epoch.generation());
                }, main).build();
        }

        void initialize() {
            initializationTimeout = () -> { completeReady(false); shutdownEngine(); };
            main.postDelayed(initializationTimeout, 10000);
            try {
                tts = new TextToSpeech(context, status -> main.post(() -> onInit(status)));
            } catch (RuntimeException error) {
                completeReady(false);
                shutdownEngine();
            }
        }

        void onInit(int status) {
            if (closed || readyResult == null) return;
            try {
                if (status != TextToSpeech.SUCCESS || tts == null) {
                    completeReady(false); shutdownEngine(); return;
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
                    completeReady(false); shutdownEngine(); return;
                }
                tts.setAudioAttributes(attributes);
                tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                    @Override public void onStart(String utteranceId) {}
                    @Override public void onDone(String utteranceId) {
                        main.post(() -> completePlayback(utteranceId, "completed"));
                    }
                    @Override public void onError(String utteranceId) {
                        main.post(() -> completePlayback(utteranceId, "unavailable"));
                    }
                    @Override public void onError(String utteranceId, int code) { onError(utteranceId); }
                    @Override public void onStop(String utteranceId, boolean interrupted) {
                        main.post(() -> completePlayback(utteranceId, "cancelled"));
                    }
                });
                completeReady(true);
            } catch (RuntimeException error) {
                completeReady(false); shutdownEngine();
            }
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

        void play(long generation, String text, MethodChannel.Result result) {
            if (closed || !foreground || !ready || tts == null || text == null ||
                    text.trim().isEmpty() || text.length() > 240) {
                result.success("unavailable"); return;
            }
            if (!epoch.cancel(generation)) { result.success("cancelled"); return; }
            cancelPlayback();
            String utteranceId = id + ":" + (++sequence);
            if (!epoch.begin(generation, utteranceId)) { result.success("cancelled"); return; }
            playbackResult = result;
            playbackTimeout = () -> {
                completePlayback(utteranceId, "unavailable");
                if (tts != null) tts.stop();
            };
            main.postDelayed(playbackTimeout, 20000);
            try {
                if (audioManager == null || audioManager.requestAudioFocus(focus) !=
                        AudioManager.AUDIOFOCUS_REQUEST_GRANTED ||
                        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId) !=
                        TextToSpeech.SUCCESS) {
                    completePlayback(utteranceId, "unavailable");
                }
            } catch (RuntimeException error) {
                completePlayback(utteranceId, "unavailable");
            }
        }

        void completePlayback(String utteranceId, String outcome) {
            if (!epoch.finish(utteranceId)) return;
            resolvePlayback(outcome);
        }
        void resolvePlayback(String outcome) {
            if (playbackTimeout != null) main.removeCallbacks(playbackTimeout);
            playbackTimeout = null;
            if (audioManager != null) audioManager.abandonAudioFocusRequest(focus);
            if (playbackResult != null) {
                MethodChannel.Result result = playbackResult;
                playbackResult = null;
                result.success(outcome);
            }
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
            if (tts != null) {
                try { tts.shutdown(); } catch (RuntimeException ignored) {}
                tts = null;
            }
            ready = false;
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
