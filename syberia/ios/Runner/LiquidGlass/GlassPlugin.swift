import Flutter
import UIKit

/// Native Liquid Glass for the Flutter UI.
///
/// Flutter draws its own pixels, so the only way to show Apple's real material
/// is to host UIKit views as platform views. The bars are long-standing UIKit
/// classes that the system itself renders as Liquid Glass on iOS 26 and newer.
enum LiquidGlass {
  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "SiberiaLiquidGlass") else { return }
    let messenger = registrar.messenger()

    let channel = FlutterMethodChannel(name: "siberia/glass", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "capabilities":
        result(LiquidGlass.capabilities)
      case "confirm":
        LiquidGlass.confirm(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    registrar.register(GlassTabBarFactory(messenger: messenger), withId: "siberia/glass_tab_bar")
    registrar.register(
      GlassBarButtonsFactory(messenger: messenger), withId: "siberia/glass_bar_buttons")
    registrar.register(GlassSurfaceFactory(messenger: messenger), withId: "siberia/glass_surface")
    registrar.register(GlassToolbarFactory(messenger: messenger), withId: "siberia/glass_toolbar")
    registrar.register(
      GlassMenuButtonFactory(messenger: messenger), withId: "siberia/glass_menu_button")
  }

  /// Asks before something that cannot be undone, the way iOS asks: an
  /// action sheet with the destructive choice and Cancel apart below it.
  /// Answers true once confirmed, false otherwise, and nil when there is
  /// nothing to present it from.
  static func confirm(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any], let presenter = topViewController() else {
      result(nil)
      return
    }
    // An iPad has no edge to bring a sheet up from, and asks in the middle.
    let style: UIAlertController.Style =
      UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
    let sheet = UIAlertController(
      title: args["title"] as? String,
      message: args["message"] as? String,
      preferredStyle: style)
    var answered = false
    func answer(_ value: Bool) {
      guard !answered else { return }
      answered = true
      result(value)
    }
    sheet.addAction(
      UIAlertAction(title: args["action"] as? String, style: .destructive) { _ in answer(true) })
    sheet.addAction(
      UIAlertAction(title: args["cancel"] as? String, style: .cancel) { _ in answer(false) })
    if let dark = args["dark"] as? Bool {
      sheet.overrideUserInterfaceStyle = dark ? .dark : .light
    }
    if let tint = args["tint"] as? NSNumber {
      sheet.view.tintColor = UIColor(argb: tint.int64Value)
    }
    presenter.present(sheet, animated: true)
  }

  /// The view controller on top of the key window, which a sheet comes up
  /// over.
  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    let window = windows.first { $0.isKeyWindow } ?? windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }

  /// Whether UIKit renders bars and effects as Liquid Glass in this process.
  static var isAvailable: Bool {
    // An app that opts out keeps the previous design even on iOS 26.
    if Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool == true {
      return false
    }
    #if compiler(>=6.2)
      if #available(iOS 26.0, *) { return true }
    #endif
    return false
  }

  /// Bar heights are measured without a window, so they exclude safe areas.
  /// Flutter uses them for its first frame; each bar reports its real size
  /// once it is on screen.
  private static var capabilities: [String: Any] {
    [
      "liquidGlass": isAvailable,
      "tabBarHeight": Double(UITabBar().sizeThatFits(.zero).height),
      "tabBarHeadroom": Double(GlassTabBarView.lensHeadroom),
      "navigationBarHeight": Double(GlassBarButtonsView.fittingHeight(of: UINavigationBar())),
      "navigationBarRoom": Double(GlassBarButtonsView.shadowRoom),
    ]
  }
}

/// A transparent container that tells its owner whenever its geometry changes.
final class GlassHostView: UIView {
  var onLayout: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onLayout?()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    onLayout?()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onLayout?()
  }
}

extension UIColor {
  /// Creates a colour from Flutter's `0xAARRGGBB` integer.
  convenience init(argb: Int64) {
    self.init(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }
}
