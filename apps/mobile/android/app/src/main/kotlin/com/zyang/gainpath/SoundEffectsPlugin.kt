package com.zyang.gainpath

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Preloads a small offline pack. All calls and stream changes run on the main thread. */
class SoundEffectsPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private var pool: SoundPool? = null
    private var foreground = false
    private var enabled = true
    private var stream = 0
    private var lastPlayed = -1000L
    private var protectedUntil = 0L
    private val samples = mutableMapOf<String, Int>()
    private val loaded = mutableSetOf<Int>()
    private val lengths = mapOf(
        "ready" to 150, "rep" to 75, "workoutComplete" to 440,
        "pointsClaimed" to 390, "gameHit" to 95, "combo" to 280, "roundEnd" to 360
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val prefs = context.getSharedPreferences("gainpath_sound_effects", Context.MODE_PRIVATE)
        enabled = prefs.getBoolean("enabled", true)
        val soundPool = SoundPool.Builder()
            .setMaxStreams(1)
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            .build()
        pool = soundPool
        soundPool.setOnLoadCompleteListener { owner, id, status ->
            if (owner == pool && status == 0) loaded.add(id)
        }
        for (name in lengths.keys) {
            val asset = binding.flutterAssets.getAssetFilePathByName("assets/audio/effects/$name.wav")
            try {
                context.assets.openFd(asset).use { samples[name] = soundPool.load(it, 1) }
            } catch (_: java.io.IOException) {
                // A missing sample disables that cue only.
            }
        }
        channel = MethodChannel(binding.binaryMessenger, "gainpath/sound_effects").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "enabled" -> result.success(enabled)
                    "setEnabled" -> {
                        val value = call.arguments as? Boolean
                        if (value == null) {
                            result.error("invalid_setting", "Expected a boolean", null)
                        } else {
                            enabled = value
                            prefs.edit().putBoolean("enabled", value).apply()
                            if (!enabled) stop()
                            result.success(true)
                        }
                    }
                    "play" -> result.success(play(call.arguments as? String))
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun setForeground(value: Boolean) {
        foreground = value
        if (!value) stop()
    }

    private fun stop() {
        if (stream != 0) pool?.stop(stream)
        stream = 0
    }

    private fun play(name: String?): Int {
        val owner = pool ?: return 0
        val length = lengths[name] ?: return 0
        val sample = samples[name] ?: return 0
        val now = SystemClock.elapsedRealtime()
        if (!foreground || !enabled || sample !in loaded) return 0
        if ((name == "gameHit" || name == "rep") &&
            (now - lastPlayed < 120 || now < protectedUntil)) return 0
        stop()
        val volume = if (name == "rep" || name == "ready") .45f else .65f
        stream = owner.play(sample, volume, volume, 1, 0, 1f)
        if (stream == 0) return 0
        lastPlayed = now
        protectedUntil = if (name == "gameHit" || name == "rep") 0 else now + length
        // Allow a small output-buffer margin for the completion handoff.
        return length + 40
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        stop()
        pool?.release()
        pool = null
        loaded.clear()
        samples.clear()
    }
}
