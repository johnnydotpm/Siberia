import Flutter
import UIKit

final class GlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    GlassSurfaceView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// Apple's glass material as a plain background. Flutter draws the content
/// above it and keeps every gesture, so the view never takes touches.
final class GlassSurfaceView: NSObject, FlutterPlatformView {
  private let host: UIView
  private let effectView = UIVisualEffectView()
  private let channel: FlutterMethodChannel
  private var material: String?

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    host = UIView(frame: frame)
    channel = FlutterMethodChannel(
      name: "siberia/glass_surface/\(viewId)", binaryMessenger: messenger)
    super.init()

    host.backgroundColor = .clear
    host.isOpaque = false
    host.isUserInteractionEnabled = false
    effectView.frame = host.bounds
    effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    host.addSubview(effectView)

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
    let radius = CGFloat((args["radius"] as? NSNumber)?.doubleValue ?? 0)
    let tintValue = (args["tint"] as? NSNumber)?.int64Value
    let tint = tintValue.map { UIColor(argb: $0) }
    let clear = args["style"] as? String == "clear"

    #if compiler(>=6.2)
      if #available(iOS 26.0, *) {
        // Replacing the effect restarts the material's own animation, so it
        // is rebuilt only when the material really changes.
        let key = "\(clear)/\(tintValue ?? -1)"
        if key != material {
          material = key
          let glass = UIGlassEffect(style: clear ? .clear : .regular)
          glass.tintColor = tint
          effectView.effect = glass
        }
        // The material follows this shape. A layer mask or a Flutter clip
        // would cut the picture but leave the glass edges rectangular.
        effectView.cornerConfiguration = .uniformCorners(radius: .fixed(radius))
        return
      }
    #endif

    effectView.effect = UIBlurEffect(style: .systemMaterial)
    effectView.contentView.backgroundColor = tint
    effectView.layer.cornerRadius = radius
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
  }
}
