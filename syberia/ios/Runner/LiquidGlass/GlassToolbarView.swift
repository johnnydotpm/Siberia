import Flutter
import UIKit

final class GlassToolbarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassToolbarView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A real `UIToolbar` with the actions on what a page has picked, in place of
/// the tab bar while it picks, as Mail and Files do. On iOS 26 UIKit floats
/// each item on Liquid Glass of its own: the first at the leading edge, the
/// last at the trailing one.
final class GlassToolbarView: NSObject, FlutterPlatformView, UIToolbarDelegate {
  /// Space above the toolbar inside the view. Glass items cast a soft shadow
  /// and grow while pressed; without room for that, both end in a visible
  /// line at the view's edge.
  static let shadowRoom: CGFloat = 16

  /// The height of a toolbar's content, used when UIKit reports less.
  private static let standardBarHeight: CGFloat = 44

  private let host: GlassHostView
  private let toolbar = UIToolbar()
  private let channel: FlutterMethodChannel
  private var actions: [(item: UIBarButtonItem, id: String)] = []
  private var itemsSignature: String?
  private var reportedHeight: CGFloat = 0

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    host = GlassHostView(frame: frame)
    channel = FlutterMethodChannel(
      name: "siberia/glass_toolbar/\(viewId)", binaryMessenger: messenger)
    super.init()

    host.backgroundColor = .clear
    host.isOpaque = false
    // Flutter composites its own layers only over this view's bounds.
    host.clipsToBounds = true

    let appearance = UIToolbarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.shadowColor = .clear
    toolbar.standardAppearance = appearance
    toolbar.compactAppearance = appearance
    toolbar.scrollEdgeAppearance = appearance
    toolbar.compactScrollEdgeAppearance = appearance
    toolbar.delegate = self
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(toolbar)
    // The toolbar keeps clear of the home indicator, as a system one does.
    NSLayoutConstraint.activate([
      toolbar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      toolbar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      toolbar.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor),
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

  func position(for bar: UIBarPositioning) -> UIBarPosition { .bottom }

  private func apply(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    if let dark = args["dark"] as? Bool {
      host.overrideUserInterfaceStyle = dark ? .dark : .light
    }
    let tint = (args["tint"] as? NSNumber).map { UIColor(argb: $0.int64Value) } ?? .systemBlue

    let specs = args["items"] as? [[String: Any]] ?? []
    // Whether an action can be taken changes often. Rebuilding the items
    // for it would make them flicker, so they are replaced only when the
    // actions themselves differ.
    let signature =
      specs
      .map { spec in
        ["id", "label", "symbol"].map { spec[$0] as? String ?? "" }.joined(separator: "\u{1F}")
      }
      .joined(separator: "\u{1E}")
    if signature != itemsSignature {
      itemsSignature = signature
      actions = specs.map { spec -> (item: UIBarButtonItem, id: String) in
        let label = spec["label"] as? String
        let item: UIBarButtonItem
        // A symbol stands in for the label, as under a message in Mail; the
        // label is still what VoiceOver says.
        if let name = spec["symbol"] as? String, let image = UIImage(systemName: name) {
          item = UIBarButtonItem(
            image: image, style: .plain, target: self, action: #selector(didTap(_:)))
          item.accessibilityLabel = label
        } else {
          item = UIBarButtonItem(
            title: label, style: .plain, target: self, action: #selector(didTap(_:)))
        }
        return (item: item, id: spec["id"] as? String ?? "")
      }
      // A lone action stands at the trailing edge, where deleting goes.
      var items: [UIBarButtonItem] = []
      for (index, action) in actions.enumerated() {
        if index > 0 || actions.count == 1 {
          items.append(.flexibleSpace())
        }
        items.append(action.item)
      }
      toolbar.setItems(items, animated: false)
    }

    for (action, spec) in zip(actions, specs) {
      action.item.isEnabled = spec["enabled"] as? Bool ?? true
      // Glass bar button items do not inherit the bar's tint, so every item
      // gets its colour explicitly.
      action.item.tintColor = spec["destructive"] as? Bool == true ? .systemRed : tint
    }
  }

  @objc private func didTap(_ sender: UIBarButtonItem) {
    guard let id = actions.first(where: { $0.item === sender })?.id else { return }
    channel.invokeMethod("tap", arguments: id)
  }

  /// Tells Flutter how tall the toolbar is, without the bottom safe area,
  /// which Flutter knows itself. It is only right once the view is in a
  /// window.
  private func reportHeight() {
    guard host.window != nil else { return }
    let fitting = toolbar.sizeThatFits(CGSize(width: host.bounds.width, height: 0)).height
    let barHeight = max(fitting, Self.standardBarHeight)
    guard abs(barHeight - reportedHeight) > 0.5 else { return }
    reportedHeight = barHeight
    channel.invokeMethod(
      "metrics",
      arguments: [
        "height": Double(barHeight),
        "room": Double(Self.shadowRoom),
      ])
  }
}
