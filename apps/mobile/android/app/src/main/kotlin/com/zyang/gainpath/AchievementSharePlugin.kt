package com.zyang.gainpath

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

/** Opens Android's chooser only after an explicit Share badge action. */
class AchievementSharePlugin : FlutterPlugin, ActivityAware {
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private val allowed = setOf(
        "I unlocked the First check-in badge in GainPath!",
        "I unlocked the Three-day check-in streak badge in GainPath!",
        "I unlocked the Seven-day check-in streak badge in GainPath!"
    )
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "gainpath/achievement_share").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "share") { result.notImplemented(); return@setMethodCallHandler }
                val text = (call.arguments as? Map<*, *>)?.get("text") as? String
                val current = activity
                if (current == null || text !in allowed) {
                    result.error("unavailable", "Achievement sharing unavailable.", null)
                    return@setMethodCallHandler
                }
                try {
                    current.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }, "Share achievement"))
                    result.success(null)
                } catch (_: Exception) { result.error("unavailable", "Achievement sharing unavailable.", null) }
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel?.setMethodCallHandler(null); channel = null }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
}
