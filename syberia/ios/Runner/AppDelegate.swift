import Flutter
import CFNetwork
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    LiquidGlass.register(with: engineBridge.pluginRegistry)
    HomeWidget.register(with: engineBridge.pluginRegistry)
    VpnStatus.register(with: engineBridge.pluginRegistry)
  }
}

/// Tells Dart whether a VPN carries the phone's traffic now, so the app can
/// say that Librus sometimes blocks VPNs only while one is on. iOS gives no
/// direct answer: a VPN shows as a scoped proxy setting on a tunnel
/// interface.
enum VpnStatus {
  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "SiberiaVpnStatus") else { return }
    let channel = FlutterMethodChannel(
      name: "app.syberia.client/vpn", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "active" {
        result(active())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static let tunnels = ["tap", "tun", "ppp", "ipsec", "utun"]

  private static func active() -> Bool? {
    guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
      let scoped = settings["__SCOPED__"] as? [String: Any]
    else { return nil }
    return scoped.keys.contains { name in
      tunnels.contains { name.hasPrefix($0) }
    }
  }
}
