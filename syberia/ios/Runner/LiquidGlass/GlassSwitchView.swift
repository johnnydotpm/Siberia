import Flutter
import UIKit

final class GlassSwitchFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassSwitchView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// UIKit's own switch. On iOS 26 the system turns its knob into a piece of
/// Liquid Glass under the finger. A flip goes to Flutter, which tells the
/// switch the value it keeps.
final class GlassSwitchView: NSObject, FlutterPlatformView {
  private let host: GlassHostView
  private let toggle = UISwitch()
  private let channel: FlutterMethodChannel
  private var reportedSize: CGSize = .zero

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    host = GlassHostView(frame: frame)
    channel = FlutterMethodChannel(
      name: "siberia/glass_switch/\(viewId)", binaryMessenger: messenger)
    super.init()

    host.backgroundColor = .clear
    host.isOpaque = false
    toggle.translatesAutoresizingMaskIntoConstraints = false
    toggle.addTarget(self, action: #selector(changed), for: .valueChanged)
    host.addSubview(toggle)
    NSLayoutConstraint.activate([
      toggle.centerXAnchor.constraint(equalTo: host.centerXAnchor),
      toggle.centerYAnchor.constraint(equalTo: host.centerYAnchor),
    ])

    apply(arguments)
    host.onLayout = { [weak self] in self?.reportSize() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.apply(call.arguments)
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { host }

  private func apply(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    if let dark = args["dark"] as? Bool {
      host.overrideUserInterfaceStyle = dark ? .dark : .light
    }
    toggle.isEnabled = args["enabled"] as? Bool ?? true
    if let value = args["value"] as? Bool, value != toggle.isOn {
      toggle.setOn(value, animated: host.window != nil)
    }
  }

  @objc private func changed() {
    channel.invokeMethod("changed", arguments: toggle.isOn)
  }

  /// Tells Flutter the size UIKit wants for the switch, which it sizes the
  /// view to.
  private func reportSize() {
    guard host.window != nil else { return }
    let size = toggle.intrinsicContentSize
    guard size.width > 0, size.height > 0,
      abs(size.width - reportedSize.width) > 0.5 || abs(size.height - reportedSize.height) > 0.5
    else { return }
    reportedSize = size
    channel.invokeMethod(
      "metrics", arguments: ["width": Double(size.width), "height": Double(size.height)])
  }
}
