import AppIntents
import WidgetKit

/// The look of one widget, chosen in the system's Edit Widget sheet.
enum WidgetThemeOption: String, AppEnum {
  case brand, system, light, dark, black

  static var typeDisplayRepresentation: TypeDisplayRepresentation { "Style" }
  static var caseDisplayRepresentations: [WidgetThemeOption: DisplayRepresentation] {
    [
      .brand: "SiberiaGB",
      .system: "System",
      .light: "Light",
      .dark: "Dark",
      .black: "Black (AMOLED)",
    ]
  }
}

/// The settings of one widget. Touch and hold the widget, then Edit Widget.
/// The English titles are the keys of Localizable.strings.
struct WidgetOptionsIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource { "Next lesson" }
  static var description: IntentDescription { "The current or next lesson with its time and room." }

  @Parameter(title: "Style", default: .brand)
  var theme: WidgetThemeOption

  @Parameter(title: "Room", default: true)
  var showRoom: Bool

  @Parameter(title: "Teacher", default: false)
  var showTeacher: Bool

  @Parameter(title: "Following lessons", default: true)
  var showNextLessons: Bool

  @Parameter(title: "Countdown", default: true)
  var showCountdown: Bool

  @Parameter(title: "Day progress", default: true)
  var showProgress: Bool

  @Parameter(title: "Highlight substitutions", default: true)
  var highlightSubstitutions: Bool

  @Parameter(title: "Merge double lessons", default: true)
  var mergeDoubleLessons: Bool
}

/// The intent's settings as plain values the views can use.
struct WidgetOptions: Hashable {
  var theme: WidgetThemeOption = .brand
  var showRoom = true
  var showTeacher = false
  var showNextLessons = true
  var showCountdown = true
  var showProgress = true
  var highlightSubstitutions = true
  var mergeDoubleLessons = true

  init() {}

  init(_ intent: WidgetOptionsIntent) {
    theme = intent.theme
    showRoom = intent.showRoom
    showTeacher = intent.showTeacher
    showNextLessons = intent.showNextLessons
    showCountdown = intent.showCountdown
    showProgress = intent.showProgress
    highlightSubstitutions = intent.highlightSubstitutions
    mergeDoubleLessons = intent.mergeDoubleLessons
  }
}
