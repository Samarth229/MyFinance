import Flutter
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?
  private var methodChannel: FlutterMethodChannel?

  func scene(_ scene: UIScene,
             willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    // FlutterAppDelegate sets up the engine; Main.storyboard creates
    // FlutterViewController and assigns it to self.window automatically.
    // We just need to register the MethodChannel on top.
    if let flutterVC = window?.rootViewController as? FlutterViewController {
      setupMethodChannel(flutterVC)
    }
    if let url = connectionOptions.urlContexts.first?.url {
      handleURL(url)
    }
  }

  func scene(_ scene: UIScene,
             openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let url = URLContexts.first?.url {
      handleURL(url)
    }
  }

  private func setupMethodChannel(_ flutterVC: FlutterViewController) {
    methodChannel = FlutterMethodChannel(
      name: "com.example.myfinance/gpay",
      binaryMessenger: flutterVC.binaryMessenger)
    methodChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "openApp":
        if let packageName = call.arguments as? String {
          self?.openApp(packageName: packageName, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected package name", details: nil))
        }
      case "getPendingWidgetAction":
        let action = UserDefaults.standard.string(forKey: "pending_widget_action")
        UserDefaults.standard.removeObject(forKey: "pending_widget_action")
        result(action)
      case "isAccessibilityEnabled":
        result(false)
      case "openAccessibilitySettings":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func openApp(packageName: String, result: @escaping FlutterResult) {
    var urlString: String?
    if packageName == "com.google.android.apps.nbu.paisa.user" {
      urlString = "googlepay://"
    } else if packageName == "com.phonepe.app" {
      urlString = "phonepe://"
    }
    guard let urlStr = urlString, let url = URL(string: urlStr) else {
      result(FlutterError(code: "NOT_FOUND", message: "App not installed", details: nil))
      return
    }
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:]) { success in
        result(success ? nil : FlutterError(code: "FAILED", message: "Could not open app", details: nil))
      }
    } else {
      result(FlutterError(code: "NOT_INSTALLED", message: "App not installed", details: nil))
    }
  }

  private func handleURL(_ url: URL) {
    guard url.scheme == "myfinance", url.host == "payment" else { return }
    UserDefaults.standard.set("payment", forKey: "pending_widget_action")
  }
}
