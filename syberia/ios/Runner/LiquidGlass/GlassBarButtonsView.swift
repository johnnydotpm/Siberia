import Flutter
import UIKit

final class GlassBarButtonsFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassBarButtonsView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A real `UINavigationBar` that carries only bar button items. On iOS 26
/// UIKit gives the items Liquid Glass backgrounds and merges neighbours into
/// one capsule, as in system apps. Flutter draws the title itself.
final class GlassBarButtonsView: NSObject, FlutterPlatformView, UINavigationBarDelegate {
  /// Space above and below the bar inside the view. Glass buttons cast a
  /// wide, soft shadow and grow while pressed; without room for that, both
  /// end in a visible line at the view's edge.
  static let shadowRoom: CGFloat = 36

  private let host: GlassHostView
  private let bar = UINavigationBar()
  private let navigationItem = UINavigationItem()
  private let channel: FlutterMethodChannel
  private var barHeight: NSLayoutConstraint?
  private var actions: [(item: UIBarButtonItem, id: String)] = []
  private var tint: UIColor = .systemBlue
  private var reportedHeight: CGFloat = 0
  private var reportedCenter: CGFloat = 0

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    host = GlassHostView(frame: frame)
    channel = FlutterMethodChannel(
      name: "siberia/glass_bar_buttons/\(viewId)", binaryMessenger: messenger)
    super.init()

    host.backgroundColor = .clear
    host.isOpaque = false
    // Flutter composites its own layers only over this view's bounds.
    host.clipsToBounds = true

    let appearance = UINavigationBarAppearance()
    appearance.configureWithTransparentBackground()
    appearance.shadowColor = .clear
    bar.standardAppearance = appearance
    bar.compactAppearance = appearance
    bar.scrollEdgeAppearance = appearance
    bar.compactScrollEdgeAppearance = appearance
    bar.delegate = self
    bar.translatesAutoresizingMaskIntoConstraints = false
    bar.setItems([navigationItem], animated: false)
    host.addSubview(bar)
    let height = bar.heightAnchor.constraint(equalToConstant: Self.fittingHeight(of: bar))
    barHeight = height
    NSLayoutConstraint.activate([
      bar.leadingAnchor.constraint(equalTo: host.leadingAnchor),
      bar.trailingAnchor.constraint(equalTo: host.trailingAnchor),
      bar.topAnchor.constraint(equalTo: host.topAnchor, constant: Self.shadowRoom),
      height,
    ])

    apply(arguments, animated: false)
    host.onLayout = { [weak self] in self?.reportHeight() }
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.apply(call.arguments, animated: true)
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { host }

  func position(for bar: UIBarPositioning) -> UIBarPosition { .top }

  private func apply(_ arguments: Any?, animated: Bool) {
    guard let args = arguments as? [String: Any] else { return }
    if let dark = args["dark"] as? Bool {
      host.overrideUserInterfaceStyle = dark ? .dark : .light
    }
    if let value = args["tint"] as? NSNumber {
      tint = UIColor(argb: value.int64Value)
    }

    actions.removeAll()
    let leading = barItems(for: args["leading"] as? [[String: Any]] ?? [])
    let trailing = barItems(for: args["trailing"] as? [[String: Any]] ?? [])
    navigationItem.setLeftBarButtonItems(leading, animated: animated)
    // UIKit places right items starting from the trailing edge.
    navigationItem.setRightBarButtonItems(Array(trailing.reversed()), animated: animated)
  }

  /// Builds the items for one side in reading order. A zero-width fixed space
  /// ends a shared glass background, which gives a button its own capsule.
  private func barItems(for specs: [[String: Any]]) -> [UIBarButtonItem] {
    var items: [UIBarButtonItem] = []
    var previousSeparated = false
    for (index, spec) in specs.enumerated() {
      let separated = spec["separated"] as? Bool ?? false
      if index > 0 && (separated || previousSeparated) {
        items.append(UIBarButtonItem.fixedSpace(0))
      }
      items.append(makeButton(spec))
      previousSeparated = separated
    }
    return items
  }

  private func makeButton(_ spec: [String: Any]) -> UIBarButtonItem {
    let button: UIBarButtonItem
    if spec["loading"] as? Bool == true {
      let spinner = UIActivityIndicatorView(style: .medium)
      spinner.startAnimating()
      button = UIBarButtonItem(customView: spinner)
    } else {
      button = UIBarButtonItem(
        image: UIImage(systemName: spec["symbol"] as? String ?? ""),
        style: .plain,
        target: self,
        action: #selector(didTap(_:)))
    }
    button.accessibilityLabel = spec["label"] as? String
    button.isEnabled = spec["enabled"] as? Bool ?? true
    // Glass bar button items do not inherit the bar's tint, so every item
    // gets its colour explicitly.
    button.tintColor = .label
    if let color = spec["color"] as? NSNumber {
      button.tintColor = UIColor(argb: color.int64Value)
    }
    #if compiler(>=6.2)
      if #available(iOS 26.0, *), spec["badge"] as? Bool == true {
        button.badge = .indicator()
      }
    #endif
    if spec["prominent"] as? Bool == true {
      button.tintColor = tint
      #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
          button.style = .prominent
        }
      #endif
    }
    actions.append((item: button, id: spec["id"] as? String ?? ""))
    return button
  }

  @objc private func didTap(_ sender: UIBarButtonItem) {
    guard let id = actions.first(where: { $0.item === sender })?.id else { return }
    channel.invokeMethod("tap", arguments: id)
  }

  /// The height UIKit wants for a navigation bar right now. Left to its
  /// intrinsic size the bar keeps the height it had before iOS 26, which
  /// leaves the glass buttons no margin.
  static func fittingHeight(of bar: UINavigationBar) -> CGFloat {
    let height = bar.sizeThatFits(CGSize(width: bar.bounds.width, height: 0)).height
    return height > 0 ? height : 44
  }

  /// Keeps the bar at UIKit's preferred height, which changes with the
  /// orientation, and tells Flutter how tall the view has to be for it and
  /// where the buttons ended up.
  private func reportHeight() {
    guard host.window != nil else { return }
    let fitting = Self.fittingHeight(of: bar)
    if let barHeight, abs(barHeight.constant - fitting) > 0.5 {
      barHeight.constant = fitting
    }
    let center = buttonsCenter()
    guard abs(fitting - reportedHeight) > 0.5 || abs(center - reportedCenter) > 0.5 else {
      return
    }
    reportedHeight = fitting
    reportedCenter = center
    channel.invokeMethod(
      "metrics",
      arguments: [
        "height": Double(fitting + Self.shadowRoom * 2),
        "inset": Double(Self.shadowRoom),
        "center": Double(center),
      ])
  }

  /// The middle of the buttons, measured from the top of the bar. The iOS 26
  /// bar is taller than its buttons and keeps them at its top edge, so the
  /// middle of the bar is not where a title lines up with them.
  private func buttonsCenter() -> CGFloat {
    bar.layoutIfNeeded()
    var top = CGFloat.greatestFiniteMagnitude
    var bottom = -CGFloat.greatestFiniteMagnitude
    var pending = bar.subviews
    while let view = pending.popLast() {
      if view.isHidden { continue }
      if view is UIControl, view.bounds.height > 0 {
        let frame = view.convert(view.bounds, to: bar)
        top = min(top, frame.minY)
        bottom = max(bottom, frame.maxY)
      } else {
        pending.append(contentsOf: view.subviews)
      }
    }
    return top < bottom ? (top + bottom) / 2 : bar.bounds.midY
  }
}
