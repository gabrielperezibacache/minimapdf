import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
      return
    }
    for context in URLContexts {
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
