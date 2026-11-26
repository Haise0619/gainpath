package com.zyang.gainpath

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import java.io.File

class AchievementShareFileProvider : FileProvider()

/** Opens Android's chooser only after an explicit Share badge action. */
class AchievementSharePlugin : FlutterPlugin, ActivityAware {
    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private val allowed = setOf(
        "I unlocked the First check-in badge in GainPath!",
        "I unlocked the Three-day check-in streak badge in GainPath!",
        "I unlocked the Seven-day check-in streak badge in GainPath!",
        "I unlocked the Two-week Champion badge in GainPath!",
        "I unlocked the First Workout badge in GainPath!",
        "I unlocked the Workout Regular badge in GainPath!",
        "I unlocked the Century Club badge in GainPath!",
        "I unlocked the Routine Finisher badge in GainPath!"
    )

    private val gameResults = setOf(
        "My Move & Catch result in GainPath!",
        "My Reach & Tap result in GainPath!"
    )

    private val pngSignature = byteArrayOf(-119, 80, 78, 71, 13, 10, 26, 10)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "gainpath/achievement_share").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "share" && call.method != "shareImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val arguments = call.arguments as? Map<*, *>
                val text = arguments?.get("text") as? String
                val current = activity
                val gameResult = call.method == "shareImage" && text != null && text in gameResults
                if (current == null || text == null || (text !in allowed && !gameResult)) {
                    result.error("unavailable", "Achievement sharing unavailable.", null)
                    return@setMethodCallHandler
                }
                try {
                    val send = if (call.method == "shareImage") {
                        val png = requireNotNull(arguments?.get("png") as? ByteArray)
                        imageIntent(current, png, text)
                    } else Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    current.startActivity(Intent.createChooser(send, if (gameResult) "Share result" else "Share achievement"))
                    result.success(null)
                } catch (_: Exception) { result.error("unavailable", "Achievement sharing unavailable.", null) }
            }
        }
    }

    private fun imageIntent(activity: Activity, png: ByteArray, text: String): Intent {
        require(png.size in pngSignature.size..2_000_000)
        require(pngSignature.indices.all { png[it] == pngSignature[it] })

        val cache = File(activity.cacheDir, "achievement-cards")
        check(cache.isDirectory || cache.mkdirs())
        val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000L
        cache.listFiles()?.filter { it.isFile && it.lastModified() < cutoff }?.forEach { it.delete() }
        val card = File.createTempFile("gainpath-achievement-", ".png", cache)
        card.writeBytes(png)
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.achievement-share", card)

        return Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, text)
            clipData = ClipData.newUri(activity.contentResolver, "GainPath share card", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel?.setMethodCallHandler(null); channel = null }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
}
