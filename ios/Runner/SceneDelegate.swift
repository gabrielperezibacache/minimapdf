import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Cold start: el PDF llega en connectionOptions, no en openURLContexts.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    queuePdfContexts(connectionOptions.urlContexts)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    queuePdfContexts(URLContexts)
  }

  private func queuePdfContexts(_ contexts: Set<UIOpenURLContext>) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    for context in contexts {
      appDelegate.queueOpenedPdfFromScene(url: context.url)
    }
  }
}

extension AppDelegate {
  /// Puente desde SceneDelegate (iOS 13+) al manejador de PDFs.
  func queueOpenedPdfFromScene(url: URL) {
    queueOpenedPdf(url: url)
  }
}
