import Flutter
import UIKit
import flutter_downloader

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "minimal_pdf/external_open"
  private var pendingPdfPath: String?
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
        let path = self.pendingPdfPath
        self.pendingPdfPath = nil
        result(path)
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
    lastQueuedSource = sourceKey
    lastQueuedAt = now

    guard let path = copyPdfToTemp(url: url) else { return }
    if let sink = eventSink {
      sink(path)
    } else {
      pendingPdfPath = path
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
    let dest = FileManager.default.temporaryDirectory
      .appendingPathComponent("external_\(Int(Date().timeIntervalSince1970 * 1000))_\(safeName)")

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

  private func hasPdfMagic(at url: URL) -> Bool {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
    defer { try? handle.close() }
    let data = handle.readData(ofLength: 5)
    guard data.count >= 5 else { return false }
    return data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46
  }
}

extension AppDelegate: FlutterStreamHandler {
  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    if let queued = pendingPdfPath {
      pendingPdfPath = nil
      events(queued)
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

private func registerPlugins(registry: FlutterPluginRegistry) {
  if !registry.hasPlugin("FlutterDownloaderPlugin") {
    FlutterDownloaderPlugin.register(
      with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!
    )
  }
}
