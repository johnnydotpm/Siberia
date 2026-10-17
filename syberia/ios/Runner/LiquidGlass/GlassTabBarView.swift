import Flutter
import UIKit

final class GlassTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassTabBarView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A real `UITabBar`. On iOS 26 UIKit draws it as a floating Liquid Glass
/// capsule and owns the selection lens, its drag gesture and the morphing.
final class GlassTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
  /// Space above the bar for the selection lens, which grows past the bar's
  /// top edge while it is pressed or dragged.
  static let lensHeadroom: CGFloat = 16

  /// The height of a tab bar's content, used when UIKit reports less.
  private static let standardBarHeight: CGFloat = 49

  private let host: GlassHostView
  private let tabBar = UITabBar()
  private let channel: FlutterMethodChannel
  private var itemsSignature: String?
  private var reportedHeight: CGFloat = 0

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    host = GlassHostView(frame: frame)
    channel = FlutterMethodChannel(
      name: "siberia/glass_tab_bar/\(viewId)", binaryMessenger: messenger)
    super.init()

    host.backgroundColor = .clear
    host.isOpaque = false
    // Flutter composites its own layers only over this view's bounds, so the
    // lens and the bar's shadow must not draw outside them.
    host.clipsToBounds = true

    let appearance = UITabBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.shadowColor = .clear
    tabBar.standardAppearance = appearance
    tabBar.scrollEdgeAppearance = appearance
    tabBar.delegate = self
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    host.addSubview(tabBar)
    // The view has no size until Flutter lays it out, and the headroom must
    // give way then instead of breaking the layout.
    let headroom = tabBar.topAnchor.constraint(
      equalTo: host.topAnchor, constant: Self.lensHeadroom)
    headroom.priority = UILayoutPriority(999)
    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      tabBar.bottomAnchor.constraint(equalTo: host.bottomAnchor),
      headroom,
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

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    guard let index = tabBar.items?.firstIndex(of: item) else { return }
    channel.invokeMethod("select", arguments: index)
  }

  private func apply(_ arguments: Any?) {
    guard let args = arguments as? [String: Any] else { return }
    if let dark = args["dark"] as? Bool {
      host.overrideUserInterfaceStyle = dark ? .dark : .light
    }
    if let tint = args["tint"] as? NSNumber {
      tabBar.tintColor = UIColor(argb: tint.int64Value)
    }

    let specs = args["items"] as? [[String: Any]] ?? []
    // Badges and the selection change often. Rebuilding the items for them
    // would reset the lens, so the items are replaced only when they differ.
    let signature =
      specs
      .map { spec in
        ["label", "symbol", "selectedSymbol"]
          .map { spec[$0] as? String ?? "" }
          .joined(separator: "\u{1F}")
      }
      .joined(separator: "\u{1E}")
    if signature != itemsSignature {
      itemsSignature = signature
      tabBar.setItems(specs.map(Self.makeItem), animated: false)
    }

    let items = tabBar.items ?? []
    for (item, spec) in zip(items, specs) {
      let badge = spec["badge"] as? String ?? ""
      item.badgeValue = badge.isEmpty ? nil : badge
    }

    // No selection is valid: the current page may not belong to any tab.
    let index = (args["selected"] as? NSNumber)?.intValue
    let selected = index.flatMap { items.indices.contains($0) ? items[$0] : nil }
    if tabBar.selectedItem !== selected {
      tabBar.selectedItem = selected
    }
  }

  private static func makeItem(_ spec: [String: Any]) -> UITabBarItem {
    let symbol = spec["symbol"] as? String ?? ""
    let selectedSymbol = spec["selectedSymbol"] as? String ?? symbol
    return UITabBarItem(
      title: spec["label"] as? String,
      image: UIImage(systemName: symbol),
      selectedImage: UIImage(systemName: selectedSymbol))
  }

  /// Tells Flutter how tall the view must be for the bar to keep its natural
  /// size. The bar extends into the bottom safe area, which is only known
  /// once the view is in a window.
  private func reportHeight() {
    guard host.window != nil else { return }
    let fitting = tabBar.sizeThatFits(CGSize(width: host.bounds.width, height: 0)).height
    let barHeight = max(fitting, Self.standardBarHeight + host.safeAreaInsets.bottom)
    guard abs(barHeight - reportedHeight) > 0.5 else { return }
    reportedHeight = barHeight
    channel.invokeMethod(
      "metrics",
      arguments: [
        "height": Double(barHeight + Self.lensHeadroom),
        "headroom": Double(Self.lensHeadroom),
      ])
  }
}
