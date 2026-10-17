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
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    registrar.register(GlassTabBarFactory(messenger: messenger), withId: "siberia/glass_tab_bar")
    registrar.register(
      GlassBarButtonsFactory(messenger: messenger), withId: "siberia/glass_bar_buttons")
    registrar.register(GlassSurfaceFactory(messenger: messenger), withId: "siberia/glass_surface")
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
