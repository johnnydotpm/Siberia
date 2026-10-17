import Flutter
import WidgetKit

/// Receives the upcoming lessons from Flutter and hands them to the widget.
enum HomeWidget {
  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "SiberiaHomeWidget") else { return }
    let channel = FlutterMethodChannel(
      name: "siberia/home_widget", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "update":
        guard let arguments = call.arguments as? [String: Any],
          let payload = arguments["payload"] as? String
        else {
          result(FlutterError(code: "invalid_arguments", message: nil, details: nil))
          return
        }
        HomeWidgetStore.write(payload)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      case "clear":
        HomeWidgetStore.write(nil)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      case "status":
        // Lets the app's settings explain a widget that gets no data.
        result([
          "group": HomeWidgetStore.groupID as Any,
          "channel": HomeWidgetStore.channel as Any,
          "shared": HomeWidgetStore.canShare,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
