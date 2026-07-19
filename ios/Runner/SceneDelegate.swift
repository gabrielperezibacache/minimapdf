import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    guard let url = URLContexts.first?.url else { return }
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
      appDelegate.queueOpenedPdfFromScene(url: url)
    }
  }
}

extension AppDelegate {
  /// Puente desde SceneDelegate (iOS 13+) al manejador de PDFs.
  func queueOpenedPdfFromScene(url: URL) {
    queueOpenedPdf(url: url)
  }
}
