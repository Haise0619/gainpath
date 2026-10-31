package com.zyang.gainpath

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/** Local Member report only. Existing invoices and Coach statements are separate. */
class WorkoutReportPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    private var payload: Map<*, *>? = null
    private var savedUri: Uri? = null
    private val guard = WorkoutReportExportGuard()
    private val worker = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(engine: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(engine.binaryMessenger, "gainpath/workout_report").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "cancel" -> { cancel(); result.success(null) }
                    "open" -> try {
                        val uri = savedUri ?: throw IllegalStateException()
                        val current = activity ?: throw IllegalStateException()
                        current.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/pdf")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success(true)
                    } catch (_: Exception) { result.error("unavailable", "No PDF viewer is available.", null) }
                    "save" -> {
                        val data = call.arguments as? Map<*, *>
                        val lines = data?.get("lines") as? List<*>
                        val reps = data?.get("repTrend") as? List<*>
                        val forms = data?.get("formTrends") as? List<*>
                        if (activity == null || pending != null || lines == null || reps == null || forms == null ||
                            lines.isEmpty() || lines.size > 100000 || lines.any { it !is String || it.length > 2000 } ||
                            reps.size > 30000 || forms.size > 10000) {
                            result.error("invalid-report", "Report cannot be saved right now.", null)
                        } else {
                            savedUri = null; pending = result; payload = data
                            try {
                                val requestCode = guard.begin().requestCode
                                activity!!.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE); type = "application/pdf"
                                    putExtra(Intent.EXTRA_TITLE, "GainPath-workout-report-${System.currentTimeMillis()}.pdf")
                                }, requestCode)
                            } catch (_: Exception) { fail("Unable to open the save dialog.") }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (!guard.ownsCode(requestCode)) return false
        // A cancelled picker can return after a different account starts another
        // export. Never apply its destination to the new request's payload.
        val token = guard.accept(requestCode) ?: return true
        val result = pending ?: return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            guard.finish(token); pending = null; payload = null; result.success(false); return true
        }
        val content = payload ?: return true
        val resolver = activity?.contentResolver ?: run { fail("Activity closed."); return true }
        worker.execute {
            try {
                render(content, { guard.isCurrent(token) }) { pdf ->
                    check(guard.isCurrent(token))
                    resolver.openOutputStream(uri, "wt").use { output ->
                        check(guard.isCurrent(token))
                        requireNotNull(output)
                        pdf.writeTo(guard.guarded(token, output))
                        check(guard.isCurrent(token))
                    }
                    check(guard.isCurrent(token))
                }
                Handler(Looper.getMainLooper()).post {
                    if (pending === result && guard.isCurrent(token)) {
                        guard.finish(token); savedUri = uri; pending = null; payload = null; result.success(true)
                    }
                }
            } catch (_: Exception) {
                if (!guard.isCurrent(token)) {
                    // ACTION_CREATE_DOCUMENT created this request's new target.
                    // Remove an interrupted partial export, never a prior report.
                    try { resolver.delete(uri, null, null) } catch (_: Exception) { /* Provider may deny cleanup. */ }
                }
                Handler(Looper.getMainLooper()).post {
                    if (pending === result && guard.isCurrent(token)) fail("PDF could not be saved. Please retry.")
                }
            }
        }
        return true
    }

    private fun render(data: Map<*, *>, active: () -> Boolean, write: (PdfDocument) -> Unit) {
        val pdf = PdfDocument()
        val purple = Color.rgb(112, 38, 222)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 10f; color = Color.rgb(35, 28, 50) }
        var pageNumber = 1
        var page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create())
        var y = 66f
        fun header() {
            paint.color = purple; paint.textSize = 15f; paint.isFakeBoldText = true
            page.canvas.drawText("GainPath | Workout progress", 36f, 35f, paint)
            paint.isFakeBoldText = false; paint.textSize = 10f; paint.color = Color.rgb(35, 28, 50)
        }
        fun finishPage() {
            paint.textSize = 8f; paint.color = Color.DKGRAY
            page.canvas.drawText("Provisional measurements | Malaysia UTC+08:00 | Page $pageNumber", 36f, 817f, paint)
            pdf.finishPage(page); paint.textSize = 10f
        }
        fun space(height: Float) {
            check(active())
            if (y + height > 786f) {
                finishPage(); pageNumber++; page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create())
                y = 66f; header()
            }
        }
        fun text(value: String) {
            val wrapped = WorkoutReportTextLayout.wrap(value) { remaining ->
                paint.breakText(remaining, true, 520f, null)
            }
            space(WorkoutReportTextLayout.blockHeight(wrapped.size, 14f, 720f))
            for (line in wrapped) {
                space(14f); paint.color = Color.rgb(35, 28, 50)
                page.canvas.drawText(line, 36f, y, paint); y += 14f
            }
        }
        try {
            header()
            val lines = (data["lines"] as List<*>).map { it as String }
            lines.take(7).forEach { text(it) }
            val reps = data["repTrend"] as List<*>
            for (chunk in reps.chunked(12)) {
                space(206f); text("MEASURED REPETITIONS | purple: full, orange: partial")
                val max = chunk.maxOf { row -> val r = row as Map<*, *>; ((r["full"] as Number).toDouble() + (r["partial"] as Number).toDouble()) }.coerceAtLeast(1.0)
                for (row in chunk) {
                    val r = row as Map<*, *>; val full = (r["full"] as Number).toDouble(); val partial = (r["partial"] as Number).toDouble()
                    paint.color = Color.DKGRAY; page.canvas.drawText(r["label"].toString(), 36f, y, paint)
                    paint.color = purple; val edge = 120f + (330 * full / max).toFloat()
                    page.canvas.drawRect(120f, y - 9f, edge, y + 1f, paint)
                    paint.color = Color.rgb(236, 151, 16); page.canvas.drawRect(edge, y - 9f, edge + (330 * partial / max).toFloat(), y + 1f, paint)
                    paint.color = Color.DKGRAY; page.canvas.drawText("${full.toInt()} / ${partial.toInt()}", 465f, y, paint); y += 15f
                }
                y += 12f
            }
            for (raw in data["formTrends"] as List<*>) {
                val group = raw as Map<*, *>; val points = group["points"] as List<*>
                if (points.isEmpty()) continue
                for (chunk in points.chunked(12)) {
                    space(245f); text("ESTIMATED FORM | separate compatible group"); text(group["label"].toString())
                    text("Each point is a capture | Malaysia time | Unassessed captures leave gaps")
                    // Heading wrapping can itself advance the page. Reserve the
                    // chart after the heading so long valid labels cannot clip it.
                    space(155f)
                    val top = y + 10f; val bottom = top + 110f
                    paint.color = Color.LTGRAY; page.canvas.drawLine(75f, top, 75f, bottom, paint); page.canvas.drawLine(75f, bottom, 545f, bottom, paint)
                    paint.color = Color.DKGRAY; page.canvas.drawText("100%", 36f, top + 5f, paint); page.canvas.drawText("0%", 45f, bottom, paint)
                    var previousX: Float? = null; var previousY: Float? = null
                    for ((i, rawPoint) in chunk.withIndex()) {
                        val p = rawPoint as Map<*, *>
                        if (p["score"] == null) {
                            // Missing observations occupy their own x-position and
                            // break the line; never interpolate across unassessed work.
                            previousX = null; previousY = null
                            continue
                        }
                        val score = (p["score"] as Number).toFloat()
                        require(score.isFinite() && score in 0f..100f)
                        val x = if (chunk.size == 1) 310f else 85f + i * (450f / (chunk.size - 1))
                        val pointY = bottom - score * 1.1f
                        paint.color = purple; paint.strokeWidth = 1.5f
                        if (previousX != null) page.canvas.drawLine(previousX, previousY!!, x, pointY, paint)
                        page.canvas.drawCircle(x, pointY, 3f, paint); previousX = x; previousY = pointY
                    }
                    paint.color = Color.DKGRAY
                    page.canvas.drawText("${(chunk.first() as Map<*, *>)["label"]} to ${(chunk.last() as Map<*, *>)["label"]}", 75f, bottom + 16f, paint)
                    y = bottom + 35f
                }
            }
            lines.drop(7).forEach { text(it) }
            finishPage(); check(active()); write(pdf)
        } finally { pdf.close() }
    }

    private fun fail(message: String) { guard.cancel(); val result = pending; pending = null; payload = null; result?.error("export-failed", message, null) }
    private fun cancel() { guard.cancel(); savedUri = null; val result = pending; pending = null; payload = null; result?.success(false) }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { this.binding = binding; activity = binding.activity; binding.addActivityResultListener(this) }
    override fun onDetachedFromActivityForConfigChanges() { binding?.removeActivityResultListener(this); binding = null; activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() { binding?.removeActivityResultListener(this); binding = null; activity = null; cancel() }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { cancel(); channel?.setMethodCallHandler(null); channel = null; worker.shutdown() }
}
