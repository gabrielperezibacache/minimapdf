import Flutter
import UIKit
import flutter_downloader

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "minimal_pdf/external_open"
  private var pendingPdfPaths: [String] = []
  private var eventSink: FlutterEventSink?
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var lastQueuedSource: String?
  private var lastQueuedAt: TimeInterval = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)

    if let url = launchOptions?[.url] as? URL {
      queueOpenedPdf(url: url)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let method = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    methodChannel = method
    method.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "disposed", message: nil, details: nil))
        return
      }
      switch call.method {
      case "getInitialPdfPath":
        if self.pendingPdfPaths.isEmpty {
          result(nil)
        } else {
          result(self.pendingPdfPaths.removeFirst())
        }
      case "openDefaultAppsSettings", "openAppSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(true)
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let events = FlutterEventChannel(
      name: "\(channelName)/events",
      binaryMessenger: messenger
    )
    eventChannel = events
    events.setStreamHandler(self)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.isFileURL || url.pathExtension.lowercased() == "pdf" {
      queueOpenedPdf(url: url)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  fileprivate func queueOpenedPdf(url: URL) {
    let sourceKey = url.absoluteString
    let now = Date().timeIntervalSince1970
    if sourceKey == lastQueuedSource, now - lastQueuedAt < 2 {
      return
    }

    guard let path = copyPdfToTemp(url: url) else { return }

    // Solo tras copia exitosa: evita bloquear reintentos si falló el copy.
    lastQueuedSource = sourceKey
    lastQueuedAt = now

    if let sink = eventSink {
      sink(path)
    } else {
      pendingPdfPaths.append(path)
    }
  }

  private func copyPdfToTemp(url: URL) -> String? {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let name = url.lastPathComponent.isEmpty ? "documento.pdf" : url.lastPathComponent
    let safeName = sanitizeFileName(name)
    // UUID evita colisión entre varios PDFs con el mismo nombre.
    let dest = FileManager.default.temporaryDirectory
      .appendingPathComponent("external_\(UUID().uuidString)_\(safeName)")

    do {
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      guard hasPdfMagic(at: dest) else {
        try? FileManager.default.removeItem(at: dest)
        return nil
      }
      return dest.path
    } catch {
      return nil
    }
  }

  private func sanitizeFileName(_ name: String) -> String {
    var cleaned = name
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "\\", with: "_")
      .replacingOccurrences(of: ":", with: "_")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty || cleaned == "." || cleaned == ".." {
      cleaned = "documento.pdf"
    }
    let hasPdf = cleaned.lowercased().hasSuffix(".pdf")
    var stem = hasPdf ? String(cleaned.dropLast(4)) : cleaned
    if stem.count > 116 {
      stem = String(stem.prefix(116))
    }
    return stem + ".pdf"
  }

  /// Busca `%PDF` en los primeros 1024 bytes (alineado con PdfHeader Dart).
  private func hasPdfMagic(at url: URL) -> Bool {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
    defer { try? handle.close() }
    let data = handle.readData(ofLength: 1024)
    guard data.count >= 4 else { return false }
    let bytes = [UInt8](data)
    let limit = bytes.count
    for i in 0...(limit - 4) {
      if bytes[i] == 0x25 && bytes[i + 1] == 0x50 &&
        bytes[i + 2] == 0x44 && bytes[i + 3] == 0x46
      {
        return true
      }
    }
    return false
  }
}

extension AppDelegate: FlutterStreamHandler {
  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    while !pendingPdfPaths.isEmpty {
      events(pendingPdfPaths.removeFirst())
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
  if !registry.hasPlugin("FlutterDownloaderPlugin"),
     let registrar = registry.registrar(forPlugin: "FlutterDownloaderPlugin")
  {
    FlutterDownloaderPlugin.register(with: registrar)
  }
}
