package com.zyang.gainpath

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import android.os.Handler
import android.os.Looper

/** Private bounded PDF preview. No URI, public URL or external app is exposed. */
class PrivatePdfPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null
    private var cache: File? = null
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var attached = false
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = true
        cache = binding.applicationContext.cacheDir
        cache?.listFiles()?.filter { it.name.startsWith("private-cert-") && it.name.endsWith(".pdf") }?.forEach { it.delete() }
        channel = MethodChannel(binding.binaryMessenger, "gainpath/private_pdf").also { ch ->
            ch.setMethodCallHandler { call, result ->
                val bytes = call.arguments as? ByteArray
                if (call.method != "render") { result.notImplemented(); return@setMethodCallHandler }
                if (bytes == null || bytes.isEmpty() || bytes.size > 5 * 1024 * 1024) {
                    result.error("invalid-file", "PDF must be under 5 MB.", null); return@setMethodCallHandler
                }
                worker.execute {
                    var temporary: File? = null
                    try {
                        temporary = File.createTempFile("private-cert-", ".pdf", cache)
                        temporary.writeBytes(bytes)
                        val pages = ArrayList<ByteArray>()
                        var renderedBytes = 0
                        ParcelFileDescriptor.open(temporary, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                            PdfRenderer(descriptor).use { pdf ->
                                if (pdf.pageCount > 20) throw IllegalArgumentException("PDF preview supports up to 20 pages.")
                                for (index in 0 until pdf.pageCount) {
                                    if (!attached) throw IllegalStateException("Preview closed.")
                                    pdf.openPage(index).use { page ->
                                        val scale = minOf(1.0, 1024.0 / maxOf(page.width, page.height))
                                        val bitmap = Bitmap.createBitmap(maxOf(1, (page.width * scale).toInt()), maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                                        try {
                                            bitmap.eraseColor(Color.WHITE)
                                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                            val output = ByteArrayOutputStream()
                                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
                                            renderedBytes += output.size()
                                            if (renderedBytes > 12 * 1024 * 1024) throw IllegalArgumentException("PDF preview is too large.")
                                            pages.add(output.toByteArray())
                                        } finally { bitmap.recycle() }
                                    }
                                }
                            }
                        }
                        Handler(Looper.getMainLooper()).post { if (attached) result.success(pages) }
                    } catch (_: Exception) {
                        Handler(Looper.getMainLooper()).post { if (attached) result.error("preview-unavailable", "PDF could not be previewed (maximum 20 pages).", null) }
                    } finally { temporary?.delete(); bytes.fill(0) }
                }
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        channel?.setMethodCallHandler(null)
        channel = null
        worker.shutdown()
    }
}
