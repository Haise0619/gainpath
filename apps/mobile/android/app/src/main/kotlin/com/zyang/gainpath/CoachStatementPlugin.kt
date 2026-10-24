package com.zyang.gainpath

import android.app.Activity
import android.content.Intent
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.Executors

/** User chooses the destination through Android Storage Access Framework. */
class CoachStatementPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var pending: MethodChannel.Result? = null
    private var lines: List<String> = emptyList()
    private var invoicePending = false
    private var lastInvoiceUri: android.net.Uri? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val requestCode = 9061
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "gainpath/coach_statement").also { ch ->
            ch.setMethodCallHandler { call, result ->
                if (call.method == "openInvoice") {
                    val uri = lastInvoiceUri
                    try {
                        if (uri == null || activity == null) throw IllegalStateException("No saved invoice")
                        activity!!.startActivity(Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/pdf")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        })
                        result.success(true)
                    } catch (_: Exception) { result.error("unavailable", "No PDF viewer is available.", null) }
                    return@setMethodCallHandler
                }
                if (call.method != "save" && call.method != "saveInvoice") { result.notImplemented(); return@setMethodCallHandler }
                val current = activity
                val values = (call.arguments as? List<*>)?.mapNotNull { it as? String }
                if (current == null || pending != null || values == null || values.size > 10000 || values.any { it.length > 1000 }) {
                    result.error("unavailable", "Statement cannot be saved right now.", null); return@setMethodCallHandler
                }
                pending = result; lines = values; invoicePending = call.method == "saveInvoice"
                try {
                    current.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                        putExtra(Intent.EXTRA_TITLE, "GainPath-${if (call.method == "saveInvoice") "membership-invoice" else "coach-statement"}-${System.currentTimeMillis()}.pdf")
                    }, requestCode)
                } catch (_: Exception) { clearError("Unable to open the save dialog.") }
            }
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != this.requestCode) return false
        val result = pending ?: return true
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { pending = null; lines = emptyList(); result.success(false); return true }
        val resolver = activity?.contentResolver ?: run { clearError("Activity closed."); return true }
        val content = lines.toList()
        val isInvoice = invoicePending
        worker.execute {
            try {
                val pdf = PdfDocument()
                try {
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f }
                    var pageNumber = 1
                    var page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create())
                    var y = 42f
                    fun draw(text: String) {
                        if (y > 790f) { pdf.finishPage(page); pageNumber++; page = pdf.startPage(PdfDocument.PageInfo.Builder(595, 842, pageNumber).create()); y = 42f }
                        page.canvas.drawText(text, 36f, y, paint); y += 17f
                    }
                    for (line in content) {
                        var remaining = line.replace('\n', ' ').replace('\r', ' ')
                        if (remaining.isEmpty()) draw("")
                        while (remaining.isNotEmpty()) {
                            val count = paint.breakText(remaining, true, 520f, null).coerceAtLeast(1)
                            draw(remaining.take(count)); remaining = remaining.drop(count)
                        }
                    }
                    pdf.finishPage(page)
                    resolver.openOutputStream(uri, "wt").use { output ->
                        if (output == null) throw IllegalStateException("No output destination")
                        pdf.writeTo(output)
                    }
                } finally { pdf.close() }
                Handler(Looper.getMainLooper()).post { if (pending === result) { if (isInvoice) lastInvoiceUri = uri; pending = null; lines = emptyList(); result.success(true) } }
            } catch (_: Exception) { Handler(Looper.getMainLooper()).post { if (pending === result) clearError("Statement could not be saved. Please retry.") } }
        }
        return true
    }
    private fun clearError(message: String) { val result = pending; pending = null; lines = emptyList(); result?.error("export-failed", message, null) }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity; binding.addActivityResultListener(this) }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
    override fun onDetachedFromActivity() { activity = null; clearError("Statement screen closed.") }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel?.setMethodCallHandler(null); channel = null; clearError("Statement screen closed."); worker.shutdown() }
}
