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
  private val pendingPaths = ArrayDeque<String>()
  private var eventSink: EventChannel.EventSink? = null
  private var lastDeliveredPath: String? = null
  private var lastDeliveredAtMs: Long = 0L

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getInitialPdfPath" -> {
            // Devuelve el primero; el EventChannel / siguientes getInitial
            // pueden drenar el resto si Dart vuelve a preguntar.
            result.success(pendingPaths.removeFirstOrNull())
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
          while (pendingPaths.isNotEmpty()) {
            events?.success(pendingPaths.removeFirst())
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
    handleOpenIntent(intent)
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    handleOpenIntent(intent)
  }

  private fun handleOpenIntent(intent: Intent?) {
    if (intent == null) return
    val action = intent.action ?: return
    if (action != Intent.ACTION_VIEW &&
      action != Intent.ACTION_SEND &&
      action != Intent.ACTION_SEND_MULTIPLE
    ) {
      return
    }

    val uris: List<Uri> = when (action) {
      Intent.ACTION_SEND -> listOfNotNull(intentExtraStream(intent))
      Intent.ACTION_SEND_MULTIPLE -> intentExtraStreamList(intent)
      else -> listOfNotNull(intent.data ?: intent.clipDataUri())
    }
    if (uris.isEmpty()) return

    for (uri in uris) {
      try {
        contentResolver.takePersistableUriPermission(
          uri,
          Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )
      } catch (_: SecurityException) {
        // No todas las URIs soportan permiso persistente; la copia suele bastar.
      }

      val path = copyUriToCache(uri) ?: continue
      deliverPath(path)
    }
  }

  private fun Intent.clipDataUri(): Uri? {
    val data = clipData ?: return null
    if (data.itemCount <= 0) return null
    return data.getItemAt(0)?.uri
  }

  private fun deliverPath(path: String) {
    val now = System.currentTimeMillis()
    if (path == lastDeliveredPath && now - lastDeliveredAtMs < 2_000L) {
      return
    }
    lastDeliveredPath = path
    lastDeliveredAtMs = now

    val sink = eventSink
    if (sink != null) {
      sink.success(path)
      return
    }

    // Cold start / sin listeners: encola (soporta SEND_MULTIPLE).
    pendingPaths.addLast(path)
  }

  private fun intentExtraStream(intent: Intent): Uri? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
      @Suppress("DEPRECATION")
      intent.getParcelableExtra(Intent.EXTRA_STREAM)
    }
  }

  private fun intentExtraStreamList(intent: Intent): List<Uri> {
    val list = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
      @Suppress("DEPRECATION")
      intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
    }
    return list?.filterNotNull().orEmpty()
  }

  private fun copyUriToCache(uri: Uri): String? {
    return try {
      val rawName = uri.lastPathSegment?.substringAfterLast('/') ?: "documento.pdf"
      val decoded = Uri.decode(rawName)
      val base = decoded.substringAfterLast(':').ifEmpty { "documento.pdf" }
      val safeName = sanitizeFileName(base)
      val out = File(cacheDir, "external_${System.currentTimeMillis()}_$safeName")
      contentResolver.openInputStream(uri)?.use { input ->
        FileOutputStream(out).use { output -> input.copyTo(output) }
      } ?: return null
      if (!hasPdfMagic(out)) {
        out.delete()
        return null
      }
      out.absolutePath
    } catch (_: Exception) {
      null
    }
  }

  private fun sanitizeFileName(name: String): String {
    var cleaned = name.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim()
    if (cleaned.isEmpty() || cleaned == "." || cleaned == "..") {
      cleaned = "documento.pdf"
    }
    if (cleaned.length > 120) {
      val ext = if (cleaned.lowercase().endsWith(".pdf")) ".pdf" else ""
      val stem = cleaned.removeSuffix(ext).take(120 - ext.length)
      cleaned = stem + ext
    }
    if (!cleaned.lowercase().endsWith(".pdf")) {
      cleaned = "$cleaned.pdf"
    }
    return cleaned
  }

  private fun hasPdfMagic(file: File): Boolean {
    if (file.length() < 5L) return false
    return try {
      file.inputStream().use { input ->
        val header = ByteArray(5)
        val read = input.read(header)
        read >= 5 &&
          header[0] == 0x25.toByte() &&
          header[1] == 0x50.toByte() &&
          header[2] == 0x44.toByte() &&
          header[3] == 0x46.toByte()
      }
    } catch (_: Exception) {
      false
    }
  }

  private fun openDefaultAppsSettings(): Boolean {
    // Android 12+: pantalla "Abrir de forma predeterminada" de esta app.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      try {
        startActivity(
          Intent(Settings.ACTION_APP_OPEN_BY_DEFAULT_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
          },
        )
        return true
      } catch (_: Exception) {
        // Fallback abajo.
      }
    }

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
