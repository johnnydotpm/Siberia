import Foundation
import Security

/// Storage shared by the app and its home screen widget.
///
/// Compiled into both targets: the app writes the lessons, the widget reads
/// them. The app is sideloaded, and the tool that re-signs it decides what
/// the two may share. An app group is the usual way; AltStore and SideStore
/// rename it, and certificate signers keep only what their provisioning
/// profile allows. Wildcard profiles, such as most ad-hoc certificates, allow
/// no app group at all, but they do allow every keychain group of the team,
/// so the keychain carries the lessons there.
enum HomeWidgetStore {
  static let defaultGroup = "group.app.siberiagb.client"
  static let payloadKey = "next_lessons_v1"

  /// The first app group this process can actually use, or nil when the
  /// signer left it without one.
  static let groupID: String? = candidates.first { group in
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil
  }

  static var defaults: UserDefaults? { groupID.flatMap { UserDefaults(suiteName: $0) } }

  /// Whether the app and the widget have any storage in common.
  static var canShare: Bool { groupID != nil || SharedKeychain.isAvailable }

  /// How they share it, for the app's settings.
  static var channel: String? {
    if groupID != nil { return "appGroup" }
    return SharedKeychain.isAvailable ? "keychain" : nil
  }

  /// Hands the lessons to the widget through every channel the signature allows.
  static func write(_ payload: String?) {
    if let defaults {
      if let payload {
        defaults.set(payload, forKey: payloadKey)
      } else {
        defaults.removeObject(forKey: payloadKey)
      }
    }
    SharedKeychain.write(payload)
  }

  static func read() -> String? {
    defaults?.string(forKey: payloadKey) ?? SharedKeychain.read()
  }

  /// Group names to try, most specific first: the list AltStore and SideStore
  /// write to Info.plist, the groups in the embedded provisioning profile
  /// (ours first), then the name the project is built with.
  private static var candidates: [String] {
    var names: [String] = []
    for bundle in bundles {
      names += bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
    }
    let profileGroups = bundles.flatMap { bundle in
      (profile(in: bundle)?["Entitlements"] as? [String: Any])?[
        "com.apple.security.application-groups"] as? [String] ?? []
    }.filter { !$0.contains("*") }
    names += profileGroups.filter { $0.localizedCaseInsensitiveContains("siberiagb") }
    names += profileGroups
    names.append(defaultGroup)
    var seen = Set<String>()
    return names.filter { seen.insert($0).inserted }
  }

  /// The widget looks at its own bundle first and then at the app's, which
  /// contains it under PlugIns.
  static var bundles: [Bundle] {
    var bundles = [Bundle.main]
    let url = Bundle.main.bundleURL
    if url.pathExtension == "appex",
      let host = Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent())
    {
      bundles.append(host)
    }
    return bundles
  }

  /// The signer's provisioning profile. It is a signed message around a
  /// property list, which is read from the middle.
  static func profile(in bundle: Bundle) -> [String: Any]? {
    guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url),
      let start = data.range(of: Data("<?xml".utf8)),
      let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
    else { return nil }
    return try? PropertyListSerialization.propertyList(
      from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any]
  }
}

/// A keychain item both the app and the widget can reach: one in a keychain
/// group of the team that signed them, which wildcard profiles grant as
/// `TEAMID.*`.
enum SharedKeychain {
  private static let service = "app.siberiagb.widget"
  private static let account = "next_lessons_v1"

  static let accessGroup: String? = teamPrefix.map { "\($0).app.siberiagb.shared" }

  /// Whether this process may use the shared item, found or not.
  static var isAvailable: Bool {
    guard let accessGroup else { return false }
    let status = SecItemCopyMatching(query(accessGroup) as CFDictionary, nil)
    return status == errSecSuccess || status == errSecItemNotFound
  }

  static func write(_ value: String?) {
    guard let accessGroup else { return }
    let item = query(accessGroup)
    guard let value else {
      SecItemDelete(item as CFDictionary)
      return
    }
    let data = Data(value.utf8)
    let status = SecItemUpdate(item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    if status == errSecItemNotFound {
      var added = item
      added[kSecValueData as String] = data
      // Readable by the widget while the phone is locked, after the first unlock.
      added[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      SecItemAdd(added as CFDictionary, nil)
    }
  }

  static func read() -> String? {
    guard let accessGroup else { return nil }
    var item = query(accessGroup)
    item[kSecReturnData as String] = true
    item[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    guard SecItemCopyMatching(item as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func query(_ group: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessGroup as String: group,
    ]
  }

  /// The team the app is signed for: from the provisioning profile, or from
  /// the access group the keychain gives a new item by default, which starts
  /// with the team.
  private static var teamPrefix: String? {
    for bundle in HomeWidgetStore.bundles {
      if let prefixes = HomeWidgetStore.profile(in: bundle)?["ApplicationIdentifierPrefix"] as? [String],
        let first = prefixes.first, !first.isEmpty
      {
        return first
      }
    }
    var probe: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "app.siberiagb.team-probe",
      kSecAttrAccount as String: "probe",
      kSecReturnAttributes as String: true,
    ]
    var result: AnyObject?
    var status = SecItemCopyMatching(probe as CFDictionary, &result)
    if status == errSecItemNotFound {
      probe[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      status = SecItemAdd(probe as CFDictionary, &result)
    }
    guard status == errSecSuccess,
      let attributes = result as? [String: Any],
      let group = attributes[kSecAttrAccessGroup as String] as? String,
      let team = group.split(separator: ".").first
    else { return nil }
    return String(team)
  }
}
