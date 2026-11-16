import Flutter
import UIKit

final class GlassSegmentedFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassSegmentedView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// UIKit's own segmented control. On iOS 26 the system draws its selection
/// as a piece of Liquid Glass that slides and stretches under the finger.
/// The choice goes back to Flutter, which tells the control what is chosen.
final class GlassSegmentedView: NSObject, FlutterPlatformView {
  private let host: GlassHostView
  private let control = DeselectableSegmentedControl()
  private let channel: FlutterMethodChannel
  private var labels: [String] = []
  private var reportedHeight: CGFloat = 0

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    host = GlassHostView(frame: frame)
    channel = FlutterMethodChannel(
      name: "siberia/glass_segmented/\(viewId)", binaryMessenger: messenger)
    super.init()

    host.backgroundColor = .clear
    host.isOpaque = false
    control.translatesAutoresizingMaskIntoConstraints = false
    control.addTarget(self, action: #selector(changed), for: .valueChanged)
    host.addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      control.centerYAnchor.constraint(equalTo: host.centerYAnchor),
    ])

    apply(arguments)
    host.onLayout = { [weak self] in self?.reportHeight() }
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
    let titles = args["labels"] as? [String] ?? []
    if titles != labels {
      labels = titles
      control.removeAllSegments()
      for (index, title) in titles.enumerated() {
        control.insertSegment(withTitle: title, at: index, animated: false)
      }
    }
    let selected = (args["selected"] as? NSNumber)?.intValue ?? -1
    control.selectedSegmentIndex =
      selected >= 0 && selected < titles.count ? selected : UISegmentedControl.noSegment
    control.isEnabled = args["enabled"] as? Bool ?? true
    control.allowsDeselect = args["emptyAllowed"] as? Bool ?? false
  }

  @objc private func changed() {
    let index = control.selectedSegmentIndex
    channel.invokeMethod(
      "select", arguments: index == UISegmentedControl.noSegment ? -1 : index)
  }

  /// Tells Flutter how tall UIKit wants the control, which it sizes the
  /// view to.
  private func reportHeight() {
    guard host.window != nil else { return }
    let height = control.intrinsicContentSize.height
    guard height > 0, abs(height - reportedHeight) > 0.5 else { return }
    reportedHeight = height
    channel.invokeMethod("metrics", arguments: ["height": Double(height)])
  }
}

/// A segmented control whose choice can be let go of, where Flutter allows
/// none: a tap on the chosen segment clears it.
private final class DeselectableSegmentedControl: UISegmentedControl {
  var allowsDeselect = false

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    let previous = selectedSegmentIndex
    super.touchesEnded(touches, with: event)
    guard allowsDeselect, previous != UISegmentedControl.noSegment,
      previous == selectedSegmentIndex,
      let touch = touches.first, bounds.contains(touch.location(in: self))
    else { return }
    selectedSegmentIndex = UISegmentedControl.noSegment
    sendActions(for: .valueChanged)
  }
}
