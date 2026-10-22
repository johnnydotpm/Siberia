/// Fixed presentation of the iOS widget. Configuration intents are not
/// required to load the standard Next lesson widget.
enum WidgetThemeOption: String {
  case brand, system, light, dark, black
}

struct WidgetOptions: Hashable {
  var theme: WidgetThemeOption = .brand
  var showRoom = true
  var showTeacher = false
  var showNextLessons = true
  var showCountdown = true
  var showProgress = true
  var highlightSubstitutions = true
  var mergeDoubleLessons = true
}
