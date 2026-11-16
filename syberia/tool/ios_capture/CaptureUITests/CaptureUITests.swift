import XCTest

/// Taps, holds and drags each control while the simulator's screen is
/// recorded. Prints where each control is, in points, and saves still
/// screenshots at rest.
final class CaptureUITests: XCTestCase {
  private func pause(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

  private func still(_ name: String) {
    let shot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: shot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
    if let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] {
      let folder = URL(fileURLWithPath: home).appendingPathComponent("capture-shots")
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }
  }

  private func run(dark: Bool) {
    let theme = dark ? "dark" : "light"
    let app = XCUIApplication()
    app.launchArguments = dark ? ["-dark"] : []
    app.launch()
    pause(2)
    print("SCALE \(theme) \(XCUIScreen.main.scale)")
    for id in ["sw-off", "sw-on", "sw-dis-off", "sw-dis-on", "seg2", "seg3"] {
      let element = app.descendants(matching: .any)[id].firstMatch
      print("FRAME \(theme) \(id) \(element.frame)")
    }
    still("\(theme)-rest")
    print("MARK \(theme) begin \(Date().timeIntervalSince1970)")

    let control = app.switches["sw-off"].firstMatch
    print("MARK \(theme) switch-tap \(Date().timeIntervalSince1970)")
    control.tap()
    pause(1.5)
    still("\(theme)-switch-on")
    control.tap()
    pause(1.5)
    print("MARK \(theme) switch-hold \(Date().timeIntervalSince1970)")
    control.press(forDuration: 2.0)
    pause(1.5)
    print("MARK \(theme) switch-drag \(Date().timeIntervalSince1970)")
    let from = control.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
    let to = control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
    from.press(forDuration: 0.6, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 1.0)
    pause(1.5)

    let segments = app.segmentedControls["seg3"].firstMatch
    print("MARK \(theme) segment-tap \(Date().timeIntervalSince1970)")
    segments.buttons.element(boundBy: 2).tap()
    pause(1.5)
    still("\(theme)-segment-last")
    segments.buttons.element(boundBy: 0).tap()
    pause(1.5)
    print("MARK \(theme) segment-hold \(Date().timeIntervalSince1970)")
    segments.buttons.element(boundBy: 0).press(forDuration: 2.0)
    pause(1.5)
    print("MARK \(theme) segment-drag \(Date().timeIntervalSince1970)")
    let first = segments.buttons.element(boundBy: 0)
      .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let last = segments.buttons.element(boundBy: 2)
      .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    first.press(forDuration: 0.6, thenDragTo: last, withVelocity: .slow, thenHoldForDuration: 1.0)
    pause(1.5)
    print("MARK \(theme) end \(Date().timeIntervalSince1970)")
    app.terminate()
  }

  func test1Light() { run(dark: false) }
  func test2Dark() { run(dark: true) }
}
