import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MyFinanceGPayPlugin")
    let channel = FlutterMethodChannel(
      name: "com.example.myfinance/gpay",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {

      case "openApp":
        let pkg = call.arguments as? String ?? ""
        var urlString = ""
        switch pkg {
        case "com.google.android.apps.nbu.paisa.user":
          urlString = "googlepay://"
        case "com.phonepe.app":
          urlString = "phonepe://"
        default:
          break
        }
        if !urlString.isEmpty, let url = URL(string: urlString),
           UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url)
          result(nil)
        } else {
          result(FlutterError(code: "NOT_INSTALLED",
                              message: "App not installed",
                              details: nil))
        }

      case "getPendingWidgetAction":
        let action = UserDefaults.standard.string(forKey: "pending_widget_action")
        UserDefaults.standard.removeObject(forKey: "pending_widget_action")
        result(action)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
