import Flutter
import UIKit

final class GlassMenuButtonFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassMenuButtonView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A clear button laid over a title that Flutter draws, which opens UIKit's
/// own menu as its primary action. On iOS 26 the system brings the menu out
/// of the title on Liquid Glass, with its liquid motion, and folds it back
/// into the title when it closes; the choice goes back to Flutter.
final class GlassMenuButtonView: NSObject, FlutterPlatformView {
  private let host: UIView
  private let button = UIButton(type: .custom)
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    host = UIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "siberia/glass_menu_button/\(viewId)", binaryMessenger: messenger)
    super.init()

    host.backgroundColor = .clear
    host.isOpaque = false
    button.frame = host.bounds
    button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    button.backgroundColor = .clear
    button.showsMenuAsPrimaryAction = true
    button.accessibilityTraits.insert(.header)
    host.addSubview(button)

    apply(arguments)
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
    button.accessibilityLabel = args["label"] as? String
    let items = args["items"] as? [[String: Any]] ?? []
    let actions = items.map { item -> UIAction in
      let id = item["id"] as? String ?? ""
      let action = UIAction(title: item["title"] as? String ?? "") { [weak self] _ in
        self?.channel.invokeMethod("pick", arguments: id)
      }
      action.state = item["selected"] as? Bool == true ? .on : .off
      return action
    }
    // One choice in force at a time, marked with a check, as a title's menu
    // of folders is in system apps.
    button.menu = UIMenu(title: "", options: .singleSelection, children: actions)
  }
}
