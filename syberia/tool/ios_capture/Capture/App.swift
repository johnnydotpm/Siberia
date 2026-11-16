import UIKit

/// Rows as the Settings app has them: switches off, on and disabled, and
/// segmented controls of two and three segments. "-dark" shows them dark.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let window = UIWindow(frame: UIScreen.main.bounds)
    if ProcessInfo.processInfo.arguments.contains("-dark") {
      window.overrideUserInterfaceStyle = .dark
    } else {
      window.overrideUserInterfaceStyle = .light
    }
    window.rootViewController = UINavigationController(rootViewController: Rows())
    window.makeKeyAndVisible()
    self.window = window
    return true
  }
}

final class Rows: UITableViewController {
  private let switches: [(String, String, Bool, Bool)] = [
    ("sw-off", "Off", false, true),
    ("sw-on", "On", true, true),
    ("sw-dis-off", "Disabled off", false, false),
    ("sw-dis-on", "Disabled on", true, false),
  ]

  init() { super.init(style: .insetGrouped) }
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Settings"
    navigationController?.navigationBar.prefersLargeTitles = true
  }

  override func numberOfSections(in tableView: UITableView) -> Int { 2 }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    section == 0 ? switches.count : 2
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.selectionStyle = .none
    if indexPath.section == 0 {
      let (id, title, on, enabled) = switches[indexPath.row]
      var content = cell.defaultContentConfiguration()
      content.text = title
      cell.contentConfiguration = content
      let control = UISwitch()
      control.isOn = on
      control.isEnabled = enabled
      control.accessibilityIdentifier = id
      cell.accessoryView = control
      return cell
    }
    let items = indexPath.row == 0 ? ["Small", "Large"] : ["Small", "Medium", "Large"]
    let control = UISegmentedControl(items: items)
    control.selectedSegmentIndex = 0
    control.accessibilityIdentifier = indexPath.row == 0 ? "seg2" : "seg3"
    control.translatesAutoresizingMaskIntoConstraints = false
    cell.contentView.addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
      control.topAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.topAnchor),
      control.bottomAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.bottomAnchor),
    ])
    return cell
  }
}
