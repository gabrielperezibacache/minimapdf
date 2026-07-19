package com.minimalpdf.minimal_pdf

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Recibe ACTION_VIEW / ACTION_SEND de PDFs y expone ajustes del sistema
 * para elegir Minimal PDF como lector por defecto.
 */
class MainActivity : FlutterActivity() {
  private val channelName = "minimal_pdf/external_open"
  private var pendingPath: String? = null
  private var eventSink: EventChannel.EventSink? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getInitialPdfPath" -> {
            val path = pendingPath
            pendingPath = null
            result.success(path)
          }
          "openDefaultAppsSettings" -> {
            result.success(openDefaultAppsSettings())
          }
          else -> result.notImplemented()
        }
      }

    EventChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "$channelName/events",
    ).setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          eventSink = events
          // Si llegó un PDF antes de que Dart escuchara el stream.
          val queued = pendingPath
          if (queued != null) {
            pendingPath = null
            events?.success(queued)
          }
        }

        override fun onCancel(arguments: Any?) {
          eventSink = null
        }
      },
    )
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    handleOpenIntent(intent, isInitial = true)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleOpenIntent(intent, isInitial = false)
  }

  private fun handleOpenIntent(intent: Intent?, isInitial: Boolean) {
    if (intent == null) return
    val action = intent.action ?: return
    if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return

    val uri: Uri? = when (action) {
      Intent.ACTION_SEND -> intentExtraStream(intent)
      else -> intent.data
    }
    if (uri == null) return

    // Conserva el permiso de lectura del content:// mientras copiamos.
    try {
      contentResolver.takePersistableUriPermission(
        uri,
        Intent.FLAG_GRANT_READ_URI_PERMISSION,
      )
    } catch (_: SecurityException) {
      // No todas las URIs soportan permiso persistente; la copia suele bastar.
    }

    val path = copyUriToCache(uri) ?: return
    deliverPath(path, isInitial)
  }

  private fun deliverPath(path: String, isInitial: Boolean) {
    val sink = eventSink
    if (!isInitial && sink != null) {
      sink.success(path)
    } else {
      pendingPath = path
      sink?.success(path)
      if (sink != null) pendingPath = null
    }
  }

  private fun intentExtraStream(intent: Intent): Uri? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
      @Suppress("DEPRECATION")
      intent.getParcelableExtra(Intent.EXTRA_STREAM)
    }
  }

  private fun copyUriToCache(uri: Uri): String? {
    return try {
      val rawName = uri.lastPathSegment?.substringAfterLast('/') ?: "documento.pdf"
      val decoded = Uri.decode(rawName)
      val base = decoded.substringAfterLast(':').ifEmpty { "documento.pdf" }
      val safeName =
        if (base.lowercase().endsWith(".pdf")) base else "$base.pdf"
      val out = File(cacheDir, "external_${System.currentTimeMillis()}_$safeName")
      contentResolver.openInputStream(uri)?.use { input ->
        FileOutputStream(out).use { output -> input.copyTo(output) }
      } ?: return null
      if (out.length() < 5L) {
        out.delete()
        return null
      }
      out.absolutePath
    } catch (_: Exception) {
      null
    }
  }

  private fun openDefaultAppsSettings(): Boolean {
    return try {
      startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
      true
    } catch (_: Exception) {
      try {
        val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
          data = Uri.parse("package:$packageName")
        }
        startActivity(details)
        true
      } catch (_: Exception) {
        false
      }
    }
  }
}
