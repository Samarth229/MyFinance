import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  // Called when app is already running and receives a URL
  override func scene(_ scene: UIScene,
                      openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    if let url = URLContexts.first?.url {
      handleURL(url)
    }
  }

  // Called when app is cold-started by a URL
  override func scene(_ scene: UIScene,
                      willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url {
      handleURL(url)
    }
  }

  private func handleURL(_ url: URL) {
    guard url.scheme == "myfinance", url.host == "payment" else { return }
    UserDefaults.standard.set("payment", forKey: "pending_widget_action")
  }
}
