import SwiftUI
import UIKit
import WidgetKit

// MARK: - Data written by the app

struct WidgetLesson: Decodable, Hashable {
  let subject: String
  let room: String
  let teacher: String
  let start: Double
  let end: Double
  let substitution: Bool

  var startDate: Date { Date(timeIntervalSince1970: start / 1000) }
  var endDate: Date { Date(timeIntervalSince1970: end / 1000) }
}

struct WidgetLabels: Decodable, Hashable {
  let now: String
  let next: String
  let `break`: String?
  let tomorrow: String?
  let substitution: String?
  let startsIn: String?
  let endsIn: String?
  let lessonsFew: String?
  let lessonsMany: String?
  let noLessons: String
  let openApp: String
}

struct WidgetPayload: Decodable {
  /// The app's language, which weekday names follow.
  let locale: String?
  let labels: WidgetLabels
  let lessons: [WidgetLesson]

  static func load() -> WidgetPayload? {
    guard let raw = HomeWidgetStore.read(), let data = raw.data(using: .utf8)
    else { return nil }
    return try? JSONDecoder().decode(WidgetPayload.self, from: data)
  }
}

/// A lesson as the widget shows it: a double lesson becomes one block.
struct LessonBlock: Hashable {
  var subject: String
  var room: String
  var teacher: String
  var start: Date
  var end: Date
  var substitution: Bool
  var count: Int
}

private let maxMergeGap: TimeInterval = 15 * 60
private let maxBreak: TimeInterval = 3 * 60 * 60
private let countdownWindow: TimeInterval = 2 * 60 * 60

/// Joins the same subject in a row into one block when [merge] is on.
func lessonBlocks(_ lessons: [WidgetLesson], merge: Bool) -> [LessonBlock] {
  var blocks: [LessonBlock] = []
  for lesson in lessons.sorted(by: { $0.start < $1.start }) {
    if merge, var last = blocks.last, last.subject == lesson.subject,
      Calendar.current.isDate(last.start, inSameDayAs: lesson.startDate),
      (0...maxMergeGap).contains(lesson.startDate.timeIntervalSince(last.end))
    {
      last.end = lesson.endDate
      last.count += 1
      last.substitution = last.substitution || lesson.substitution
      if !lesson.room.isEmpty, !last.room.split(separator: "/").contains(Substring(lesson.room)) {
        last.room = last.room.isEmpty ? lesson.room : "\(last.room)/\(lesson.room)"
      }
      blocks[blocks.count - 1] = last
    } else {
      blocks.append(
        LessonBlock(
          subject: lesson.subject, room: lesson.room, teacher: lesson.teacher,
          start: lesson.startDate, end: lesson.endDate, substitution: lesson.substitution, count: 1))
    }
  }
  return blocks
}

// MARK: - Timeline

struct LessonEntry: TimelineEntry {
  let date: Date
  /// Nil until the app has written anything, e.g. right after installing.
  let labels: WidgetLabels?
  /// Today's and later lessons, merged as the options ask.
  let blocks: [LessonBlock]
  var locale: Locale = .current
  var options = WidgetOptions()

  var remaining: [LessonBlock] { blocks.filter { $0.end > date } }
  var main: LessonBlock? { remaining.first }
  var isOngoing: Bool { main.map { $0.start <= date } ?? false }
  var later: [LessonBlock] { options.showNextLessons ? Array(remaining.dropFirst()) : [] }

  var isBreak: Bool {
    guard !isOngoing, let main, let previous = blocks.last(where: { $0.end <= date }) else { return false }
    let calendar = Calendar.current
    return calendar.isDate(previous.end, inSameDayAs: date)
      && calendar.isDate(main.start, inSameDayAs: date)
      && main.start.timeIntervalSince(previous.end) <= maxBreak
  }

  /// When the countdown runs to: the end of this lesson or the start of the next.
  var countdownTarget: Date? {
    guard options.showCountdown, let main else { return nil }
    if isOngoing { return main.end }
    return main.start.timeIntervalSince(date) <= countdownWindow ? main.start : nil
  }

  var dayBlocks: [LessonBlock] {
    guard let main else { return [] }
    return blocks.filter { Calendar.current.isDate($0.start, inSameDayAs: main.start) }
  }

  var flagged: Bool { options.highlightSubstitutions && main?.substitution == true }

  /// "Now", "Break", "Next lesson", or the day when the lesson is not today.
  var status: String {
    guard let labels, let main else { return "" }
    if isOngoing { return labels.now }
    if isBreak, let label = labels.break, !label.isEmpty { return label }
    return day(of: main, short: false) ?? labels.next
  }

  func day(of lesson: LessonBlock, short: Bool) -> String? {
    let calendar = Calendar.current
    if calendar.isDate(lesson.start, inSameDayAs: date) { return nil }
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
      calendar.isDate(lesson.start, inSameDayAs: tomorrow),
      let label = labels?.tomorrow, !label.isEmpty
    {
      return label
    }
    let style: Date.FormatStyle.Symbol.Weekday = short ? .abbreviated : .wide
    let name = lesson.start.formatted(Date.FormatStyle(locale: locale).weekday(style))
    return name.prefix(1).uppercased() + name.dropFirst()
  }

  /// "2 lessons" for a double lesson, with the language's plural form.
  func count(of lesson: LessonBlock) -> String? {
    guard lesson.count > 1 else { return nil }
    let n = lesson.count
    let few = (2...4).contains(n % 10) && !(12...14).contains(n % 100)
    guard let template = few ? labels?.lessonsFew : labels?.lessonsMany, !template.isEmpty else {
      return nil
    }
    return template.replacingOccurrences(of: "%d", with: "\(n)")
  }

  /// Count, room, teacher and substitution, e.g. "2 lekcje · s. 214".
  func detail(of lesson: LessonBlock, substitution: Bool, teacher: Bool = false) -> String {
    var parts: [String] = []
    if let count = count(of: lesson) { parts.append(count) }
    if options.showRoom, !lesson.room.isEmpty { parts.append("s. \(lesson.room)") }
    if teacher, options.showTeacher, !lesson.teacher.isEmpty { parts.append(lesson.teacher) }
    if substitution, lesson.substitution, let label = labels?.substitution, !label.isEmpty {
      parts.append(label)
    }
    return parts.joined(separator: " · ")
  }

  /// A later lesson's time, with its day when that differs from the main lesson's.
  func rowMeta(of lesson: LessonBlock) -> String {
    let time = Date.FormatStyle(date: .omitted, time: .shortened)
    var start = lesson.start.formatted(time)
    if lesson.count > 1 { start += "–\(lesson.end.formatted(time))" }
    if let main, !Calendar.current.isDate(lesson.start, inSameDayAs: main.start),
      let day = day(of: lesson, short: true)
    {
      start = "\(day) \(start)"
    }
    return [start, detail(of: lesson, substitution: true)].filter { !$0.isEmpty }
      .joined(separator: " · ")
  }

  var countdownTemplate: String {
    let template = (isOngoing ? labels?.endsIn : labels?.startsIn) ?? ""
    if template.contains("%s") { return template }
    return template.isEmpty ? "%s" : "\(template) %s"
  }
}

/// The default widget uses WidgetKit directly. It must be able to request a
/// timeline even when a sideloaded build cannot resolve App Intents metadata.
struct LessonProvider: TimelineProvider {
  func placeholder(in context: Context) -> LessonEntry { .sample(WidgetOptions()) }

  func getSnapshot(in context: Context, completion: @escaping (LessonEntry) -> Void) {
    completion(LessonTimeline.snapshot(payload: WidgetPayload.load(), preview: context.isPreview))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<LessonEntry>) -> Void) {
    completion(LessonTimeline.timeline(payload: WidgetPayload.load()))
  }
}

/// An optional, separately registered widget keeps per-widget customization
/// for installations where the system can resolve its configuration intent.
struct ConfigurableLessonProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> LessonEntry { .sample(WidgetOptions()) }

  func snapshot(for configuration: WidgetOptionsIntent, in context: Context) async -> LessonEntry {
    LessonTimeline.snapshot(
      payload: WidgetPayload.load(), options: WidgetOptions(configuration), preview: context.isPreview)
  }

  func timeline(for configuration: WidgetOptionsIntent, in context: Context) async -> Timeline<LessonEntry> {
    LessonTimeline.timeline(payload: WidgetPayload.load(), options: WidgetOptions(configuration))
  }
}

/// Both providers use identical lesson selection and refresh rules.
enum LessonTimeline {
  static func snapshot(
    payload: WidgetPayload?, options: WidgetOptions = WidgetOptions(), preview: Bool,
    now: Date = Date()
  ) -> LessonEntry {
    let entry = entry(at: now, payload: payload, options: options)
    return preview && entry.remaining.isEmpty ? .sample(options) : entry
  }

  static func timeline(
    payload: WidgetPayload?, options: WidgetOptions = WidgetOptions(), now: Date = Date()
  ) -> Timeline<LessonEntry> {
    guard let payload else {
      // Reload requests from the app can be coalesced, or arrive before shared
      // storage is readable. Always give WidgetKit another chance to read it.
      return Timeline(
        entries: [entry(at: now, payload: nil, options: options)],
        policy: .after(now.addingTimeInterval(5 * 60)))
    }
    // A new entry at every lesson start and end, and when a lesson comes
    // close enough for its countdown, keeps the widget right through the day
    // without waking the app.
    let boundaries = payload.lessons
      .flatMap { [$0.startDate.addingTimeInterval(-countdownWindow), $0.startDate, $0.endDate] }
      .filter { $0 > now }
    let dates = [now] + Array(Set(boundaries)).sorted().prefix(60)
    let entries = dates.map { entry(at: $0, payload: payload, options: options) }
    // Re-read shared storage periodically, including empty or exhausted
    // payloads, without relying exclusively on reload requests from the app.
    let refresh = min(now.addingTimeInterval(15 * 60), dates.last!.addingTimeInterval(5 * 60))
    return Timeline(entries: entries, policy: .after(refresh))
  }

  private static func entry(at date: Date, payload: WidgetPayload?, options: WidgetOptions) -> LessonEntry {
    LessonEntry(
      date: date,
      labels: payload?.labels,
      blocks: lessonBlocks(payload?.lessons ?? [], merge: options.mergeDoubleLessons),
      locale: payload?.locale.map { Locale(identifier: $0) } ?? .current,
      options: options)
  }
}

extension LessonEntry {
  static func sample(_ options: WidgetOptions) -> LessonEntry {
    let now = Date()
    func lesson(_ subject: String, _ room: String, _ minutes: Double) -> WidgetLesson {
      let start = now.addingTimeInterval(minutes * 60).timeIntervalSince1970 * 1000
      return WidgetLesson(
        subject: subject, room: room, teacher: "", start: start, end: start + 45 * 60_000,
        substitution: false)
    }
    return LessonEntry(
      date: now,
      labels: WidgetLabels(
        now: "Teraz", next: "Następna lekcja", break: "Przerwa", tomorrow: "Jutro",
        substitution: "Zastępstwo", startsIn: "za %s", endsIn: "koniec za %s",
        lessonsFew: "%d lekcje", lessonsMany: "%d lekcji", noLessons: "", openApp: ""),
      blocks: lessonBlocks(
        [lesson("historia", "214", 10), lesson("matematyka", "110", 60), lesson("fizyka", "17", 115)],
        merge: options.mergeDoubleLessons),
      options: options)
  }
}

// MARK: - Themes

/// The colours of one widget theme.
struct WidgetPalette {
  let background: LinearGradient
  let text: Color
  let secondary: Color
  let line: Color
  let pill: Color
  let warning: Color

  static func of(_ theme: WidgetThemeOption, _ scheme: ColorScheme) -> WidgetPalette {
    func rgb(_ hex: UInt32) -> Color {
      Color(
        red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255)
    }
    func gradient(_ from: Color, _ to: Color) -> LinearGradient {
      LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    let amber = rgb(0xFFC46B)
    let deepAmber = rgb(0xB36B00)
    switch theme {
    case .brand:
      let colors = scheme == .dark ? (rgb(0x145571), rgb(0x0C3446)) : (rgb(0x1E7DA6), rgb(0x135977))
      return WidgetPalette(
        background: gradient(colors.0, colors.1), text: .white, secondary: .white.opacity(0.72),
        line: .white.opacity(0.2), pill: .white.opacity(0.18), warning: amber)
    case .system:
      let background = Color(uiColor: .systemBackground)
      let dark = scheme == .dark
      return WidgetPalette(
        background: gradient(background, background), text: .primary, secondary: .secondary,
        line: .primary.opacity(0.15), pill: rgb(0x1E7DA6).opacity(dark ? 0.45 : 0.14),
        warning: dark ? amber : deepAmber)
    case .light:
      return WidgetPalette(
        background: gradient(.white, rgb(0xEEF3F6)), text: rgb(0x0F1C24), secondary: rgb(0x56646E),
        line: rgb(0x0F1C24).opacity(0.12), pill: rgb(0x176B8F).opacity(0.1), warning: deepAmber)
    case .dark:
      return WidgetPalette(
        background: gradient(rgb(0x262C31), rgb(0x1B2024)), text: .white,
        secondary: .white.opacity(0.7), line: .white.opacity(0.16), pill: .white.opacity(0.14),
        warning: amber)
    case .black:
      return WidgetPalette(
        background: gradient(.black, .black), text: .white, secondary: .white.opacity(0.65),
        line: .white.opacity(0.18), pill: .white.opacity(0.16), warning: amber)
    }
  }
}

// MARK: - Views

private func timeRange(_ lesson: LessonBlock) -> String {
  let time = Date.FormatStyle(date: .omitted, time: .shortened)
  return "\(lesson.start.formatted(time))–\(lesson.end.formatted(time))"
}

/// "za 12:34": the label around a live timer.
private func countdown(to target: Date, template: String) -> Text {
  let parts = template.components(separatedBy: "%s")
  let prefix = parts.first ?? ""
  let suffix = parts.count > 1 ? parts[1] : ""
  return Text(prefix) + Text(target, style: .timer) + Text(suffix)
}

struct LessonWidgetView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var scheme
  let entry: LessonEntry

  private var palette: WidgetPalette { .of(entry.options.theme, scheme) }

  var body: some View {
    switch family {
    case .accessoryInline: inline
    case .accessoryRectangular: rectangular
    case .systemMedium: medium.foregroundStyle(palette.text)
    default: small.foregroundStyle(palette.text)
    }
  }

  // Lock screen

  @ViewBuilder private var inline: some View {
    if let lesson = entry.main {
      Text("\(lesson.start.formatted(date: .omitted, time: .shortened)) \(lesson.subject)")
    } else {
      Text(entry.labels?.noLessons ?? "SiberiaGB")
    }
  }

  @ViewBuilder private var rectangular: some View {
    if let lesson = entry.main {
      VStack(alignment: .leading, spacing: 1) {
        if let target = entry.countdownTarget {
          countdown(to: target, template: entry.countdownTemplate)
            .font(.caption2.weight(.semibold)).monospacedDigit().widgetAccentable()
        } else {
          Text(entry.status).font(.caption2.weight(.semibold)).widgetAccentable()
        }
        Text(lesson.subject).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
        Text(
          [timeRange(lesson), entry.detail(of: lesson, substitution: true)].filter { !$0.isEmpty }
            .joined(separator: " · ")
        )
        .font(.caption).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Text(emptyText).font(.caption)
    }
  }

  // Home screen

  @ViewBuilder private var small: some View {
    if let lesson = entry.main {
      mainLesson(lesson)
    } else {
      empty
    }
  }

  @ViewBuilder private var medium: some View {
    if let lesson = entry.main {
      HStack(alignment: .top, spacing: 14) {
        mainLesson(lesson)
        if !entry.later.isEmpty {
          Rectangle().fill(palette.line).frame(width: 1)
          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(entry.later.prefix(3)), id: \.self) { later in
              VStack(alignment: .leading, spacing: 2) {
                Text(entry.rowMeta(of: later))
                  .font(.caption2)
                  .foregroundStyle(
                    entry.options.highlightSubstitutions && later.substitution
                      ? palette.warning : palette.secondary
                  )
                  .lineLimit(1)
                Text(later.subject)
                  .font(.footnote.weight(.semibold))
                  .lineLimit(2)
                  .minimumScaleFactor(0.85)
              }
            }
            Spacer(minLength: 0)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
      }
    } else {
      empty
    }
  }

  private func mainLesson(_ lesson: LessonBlock) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      labelRow(lesson)
      Text(lesson.subject)
        .font(.system(size: 16, weight: .bold))
        .lineLimit(4)
        // A long subject shrinks before it is cut.
        .minimumScaleFactor(0.72)
        .padding(.top, 8)
      Spacer(minLength: 6)
      Text(timeRange(lesson))
        .font(.system(size: 14, weight: .semibold))
        .monospacedDigit()
      if let target = entry.countdownTarget {
        countdown(to: target, template: entry.countdownTemplate)
          .font(.system(size: 12, weight: .semibold))
          .monospacedDigit()
          .lineLimit(1)
          .padding(.top, 2)
      }
      let detail = entry.detail(of: lesson, substitution: !entry.flagged, teacher: true)
      if !detail.isEmpty {
        Text(detail).font(.caption).foregroundStyle(palette.secondary).lineLimit(1).padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  /// The status, the substitution flag and the day's progress, as many as fit.
  private func labelRow(_ lesson: LessonBlock) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 6) {
        pill
        if entry.flagged { flag }
        Spacer(minLength: 4)
        if entry.options.showProgress { dots(lesson) }
      }
      HStack(spacing: 6) {
        pill
        if entry.flagged { flag }
        Spacer(minLength: 0)
      }
      HStack(spacing: 6) {
        pill
        Spacer(minLength: 0)
      }
    }
  }

  private var pill: some View {
    Text(entry.status)
      .font(.system(size: 10, weight: .semibold))
      .tracking(0.6)
      .textCase(.uppercase)
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(palette.pill, in: Capsule())
  }

  private var flag: some View {
    Text(entry.labels?.substitution ?? "")
      .font(.system(size: 10, weight: .semibold))
      .tracking(0.6)
      .textCase(.uppercase)
      .lineLimit(1)
      .fixedSize()
      .foregroundStyle(Color(red: 0x3D / 255, green: 0x2A / 255, blue: 0))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color(red: 1, green: 0xC4 / 255, blue: 0x6B / 255), in: Capsule())
  }

  @ViewBuilder private func dots(_ lesson: LessonBlock) -> some View {
    let day = entry.dayBlocks
    if (2...10).contains(day.count), let current = day.firstIndex(of: lesson) {
      HStack(spacing: 4) {
        ForEach(day.indices, id: \.self) { index in
          Circle()
            .fill(index == current ? palette.text : index < current ? palette.secondary : palette.line)
            .frame(width: 6, height: 6)
        }
      }
      .fixedSize()
    }
  }

  private var empty: some View {
    VStack(spacing: 8) {
      Text("SiberiaGB")
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(palette.pill, in: Capsule())
      Text(emptyText)
        .font(.footnote.weight(.semibold))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var emptyText: String {
    if !HomeWidgetStore.canShare { return WidgetStrings.noSharedStorage }
    guard let labels = entry.labels else { return WidgetStrings.openApp }
    return labels.noLessons
  }
}

// MARK: - Widget

/// Texts the system shows before the app has written any labels.
enum WidgetStrings {
  private static var language: String {
    Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "pl"
  }

  static var name: String {
    switch language {
    case "ru": return "Следующий урок"
    case "uk": return "Наступний урок"
    case "de": return "Nächste Stunde"
    case "en": return "Next lesson"
    default: return "Następna lekcja"
    }
  }

  static var configurableName: String {
    switch language {
    case "ru": return "Следующий урок · настройки"
    case "uk": return "Наступний урок · налаштування"
    case "de": return "Nächste Stunde · anpassbar"
    case "en": return "Next lesson · customizable"
    default: return "Następna lekcja · konfigurowalna"
    }
  }

  static var description: String {
    switch language {
    case "ru": return "Текущий или следующий урок: время и кабинет."
    case "uk": return "Поточний або наступний урок: час і кабінет."
    case "de": return "Die aktuelle oder nächste Stunde mit Zeit und Raum."
    case "en": return "The current or next lesson with its time and room."
    default: return "Bieżąca lub następna lekcja z godziną i salą."
    }
  }

  /// The signer gave the app and the widget no common app group.
  static var noSharedStorage: String {
    switch language {
    case "ru": return "Установщик не дал виджету доступ к данным приложения (App Group)"
    case "uk": return "Інсталятор не дав віджету доступу до даних застосунку (App Group)"
    case "de": return "Das Installationsprogramm gibt dem Widget keinen Zugriff auf die App-Daten (App Group)"
    case "en": return "The installer gave the widget no access to the app data (App Group)"
    default: return "Instalator nie dał widżetowi dostępu do danych aplikacji (App Group)"
    }
  }

  static var openApp: String {
    switch language {
    case "ru": return "Откройте SiberiaGB, чтобы загрузить расписание"
    case "uk": return "Відкрийте SiberiaGB, щоб завантажити розклад"
    case "de": return "Öffne SiberiaGB, um den Stundenplan zu laden"
    case "en": return "Open SiberiaGB to load your timetable"
    default: return "Otwórz SiberiaGB, aby pobrać plan lekcji"
    }
  }
}

struct NextLessonWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NextLessonWidget", provider: LessonProvider()) { entry in
      LessonWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          ThemedBackground(theme: entry.options.theme)
        }
    }
    .configurationDisplayName(WidgetStrings.name)
    .description(WidgetStrings.description)
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}

struct ConfigurableNextLessonWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: "ConfigurableNextLessonWidget", intent: WidgetOptionsIntent.self,
      provider: ConfigurableLessonProvider()
    ) { entry in
      LessonWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          ThemedBackground(theme: entry.options.theme)
        }
    }
    .configurationDisplayName(WidgetStrings.configurableName)
    .description(WidgetStrings.description)
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}

/// The widget's background in its theme, following light and dark mode.
private struct ThemedBackground: View {
  @Environment(\.colorScheme) private var scheme
  let theme: WidgetThemeOption

  var body: some View { WidgetPalette.of(theme, scheme).background }
}

@main
struct SiberiaWidgetBundle: WidgetBundle {
  var body: some Widget {
    NextLessonWidget()
    ConfigurableNextLessonWidget()
  }
}
