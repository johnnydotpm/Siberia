import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'domain/models.dart';
import 'l10n/app_localizations.dart';

/// How far ahead the widget knows the timetable. It picks the current and
/// next lesson from the clock itself, so it stays right between syncs.
const homeWidgetHorizon = Duration(days: 14);
const homeWidgetMaxLessons = 60;

/// The data the home screen widgets on iOS and Android read: today's and
/// upcoming lessons and the labels to show, already translated in the app's
/// language. Today's past lessons are included so the widget can tell a break
/// from the start of the day and show the day's progress.
String buildHomeWidgetPayload(
  AppSnapshot data,
  DateTime now,
  AppLocalizations l10n, {
  Map<String, String> shortNames = const {},
}) {
  final today = DateTime(now.year, now.month, now.day);
  final until = now.add(homeWidgetHorizon);
  final lessons =
      data.lessons
          .where(
            (lesson) =>
                !lesson.cancelled &&
                lesson.end.isAfter(today) &&
                lesson.start.isBefore(until),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return jsonEncode({
    'v': 1,
    'generatedAt': now.millisecondsSinceEpoch,
    // Weekday names on the widget follow the app's language, not the phone's.
    'locale': l10n.locale.languageCode,
    'labels': {
      'now': l10n.text('widgetNow'),
      'next': l10n.text('widgetNext'),
      'break': l10n.text('widgetBreak'),
      'tomorrow': l10n.text('widgetTomorrow'),
      'substitution': l10n.text('substitution'),
      'startsIn': l10n.text('widgetStartsIn'),
      'endsIn': l10n.text('widgetEndsIn'),
      'lessonsFew': l10n.text('widgetLessonsFew'),
      'lessonsMany': l10n.text('widgetLessonsMany'),
      'noLessons': l10n.text('widgetNoLessons'),
      'openApp': l10n.text('widgetOpenApp'),
    },
    'lessons': [
      for (final lesson in lessons.take(homeWidgetMaxLessons))
        {
          'subject': displaySubject(lesson.subject, shortNames),
          'room': lesson.room,
          'teacher': lesson.teacher,
          'start': lesson.start.millisecondsSinceEpoch,
          'end': lesson.end.millisecondsSinceEpoch,
          'substitution': lesson.substitution,
        },
    ],
  });
}

/// The student's own short name for [subject], if they gave it one.
/// The student's short name for [subject], or the subject with a capital
/// first letter: some schools write every subject in lower case.
String displaySubject(String subject, Map<String, String> shortNames) {
  final short = shortNames[subject]?.trim() ?? '';
  if (short.isNotEmpty) return short;
  if (subject.isEmpty) return subject;
  return subject[0].toUpperCase() + subject.substring(1);
}

/// The look of one widget.
enum HomeWidgetTheme { brand, system, light, dark, black, translucent }

/// What one Android home screen widget looks like and shows.
/// The iOS widget uses a fixed presentation.
@immutable
class HomeWidgetConfig {
  const HomeWidgetConfig({
    this.theme = HomeWidgetTheme.brand,
    this.showRoom = true,
    this.showTeacher = false,
    this.showNextLessons = true,
    this.showCountdown = true,
    this.showProgress = true,
    this.highlightSubstitutions = true,
    this.mergeDoubleLessons = true,
  });

  factory HomeWidgetConfig.fromJson(Map<String, Object?> json) {
    const defaults = HomeWidgetConfig();
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key]! as bool : fallback;
    return HomeWidgetConfig(
      theme: HomeWidgetTheme.values.firstWhere(
        (theme) => theme.name == json['theme'],
        orElse: () => defaults.theme,
      ),
      showRoom: flag('showRoom', defaults.showRoom),
      showTeacher: flag('showTeacher', defaults.showTeacher),
      showNextLessons: flag('showNextLessons', defaults.showNextLessons),
      showCountdown: flag('showCountdown', defaults.showCountdown),
      showProgress: flag('showProgress', defaults.showProgress),
      highlightSubstitutions: flag(
        'highlightSubstitutions',
        defaults.highlightSubstitutions,
      ),
      mergeDoubleLessons: flag(
        'mergeDoubleLessons',
        defaults.mergeDoubleLessons,
      ),
    );
  }

  final HomeWidgetTheme theme;
  final bool showRoom;
  final bool showTeacher;
  final bool showNextLessons;
  final bool showCountdown;
  final bool showProgress;
  final bool highlightSubstitutions;
  final bool mergeDoubleLessons;

  Map<String, Object> toJson() => {
    'theme': theme.name,
    'showRoom': showRoom,
    'showTeacher': showTeacher,
    'showNextLessons': showNextLessons,
    'showCountdown': showCountdown,
    'showProgress': showProgress,
    'highlightSubstitutions': highlightSubstitutions,
    'mergeDoubleLessons': mergeDoubleLessons,
  };

  HomeWidgetConfig copyWith({
    HomeWidgetTheme? theme,
    bool? showRoom,
    bool? showTeacher,
    bool? showNextLessons,
    bool? showCountdown,
    bool? showProgress,
    bool? highlightSubstitutions,
    bool? mergeDoubleLessons,
  }) => HomeWidgetConfig(
    theme: theme ?? this.theme,
    showRoom: showRoom ?? this.showRoom,
    showTeacher: showTeacher ?? this.showTeacher,
    showNextLessons: showNextLessons ?? this.showNextLessons,
    showCountdown: showCountdown ?? this.showCountdown,
    showProgress: showProgress ?? this.showProgress,
    highlightSubstitutions:
        highlightSubstitutions ?? this.highlightSubstitutions,
    mergeDoubleLessons: mergeDoubleLessons ?? this.mergeDoubleLessons,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetConfig &&
      other.theme == theme &&
      other.showRoom == showRoom &&
      other.showTeacher == showTeacher &&
      other.showNextLessons == showNextLessons &&
      other.showCountdown == showCountdown &&
      other.showProgress == showProgress &&
      other.highlightSubstitutions == highlightSubstitutions &&
      other.mergeDoubleLessons == mergeDoubleLessons;

  @override
  String toString() => 'HomeWidgetConfig(${toJson()})';

  @override
  int get hashCode => Object.hash(
    theme,
    showRoom,
    showTeacher,
    showNextLessons,
    showCountdown,
    showProgress,
    highlightSubstitutions,
    mergeDoubleLessons,
  );
}

/// A widget the student has placed on the Android home screen.
@immutable
class PlacedHomeWidget {
  const PlacedHomeWidget({required this.id, this.width = 0, this.height = 0});

  final int id;

  /// Its size in dp, 0 when the launcher has not reported one.
  final int width;
  final int height;
}

/// Whether the iOS widget can read what the app writes.
@immutable
class HomeWidgetStatus {
  const HomeWidgetStatus({required this.shared, this.group});

  /// False when the tool that signed the app left the app and the widget
  /// without a common app group.
  final bool shared;
  final String? group;
}

/// Talks to the native widget code. Where there is no widget (web, desktop,
/// tests) every call quietly does nothing.
class HomeWidgetBridge {
  const HomeWidgetBridge();

  static const _channel = MethodChannel('siberia/home_widget');

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Whether widgets have per-widget settings in the app (Android only).
  bool get configurableInApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> update(String payload) =>
      _invoke<void>('update', {'payload': payload});

  Future<void> clear() => _invoke<void>('clear');

  Future<List<PlacedHomeWidget>> placedWidgets() async {
    if (!configurableInApp) return const [];
    final raw = await _invoke<List<Object?>>('placedWidgets') ?? const [];
    return [
      for (final item in raw.whereType<Map<Object?, Object?>>())
        PlacedHomeWidget(
          id: (item['id'] as num?)?.toInt() ?? 0,
          width: (item['width'] as num?)?.toInt() ?? 0,
          height: (item['height'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  Future<HomeWidgetConfig> loadConfig(int id) async {
    final raw = await _invoke<String>('loadConfig', {'id': id});
    if (raw == null) return const HomeWidgetConfig();
    try {
      return HomeWidgetConfig.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      return const HomeWidgetConfig();
    }
  }

  Future<void> saveConfig(int id, HomeWidgetConfig config) => _invoke<void>(
    'saveConfig',
    {'id': id, 'config': jsonEncode(config.toJson())},
  );

  /// Whether the iOS widget can get the app's data, or null where there is
  /// nothing to tell (Android, web, tests).
  Future<HomeWidgetStatus?> status() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    final raw = await _invoke<Map<Object?, Object?>>('status');
    if (raw == null) return null;
    return HomeWidgetStatus(
      shared: raw['shared'] == true,
      group: raw['group'] as String?,
    );
  }

  /// Whether the widget can take its colours from the wallpaper (Android 12+).
  Future<bool> dynamicColorsSupported() async =>
      await _invoke<bool>('dynamicColorsSupported') ?? false;

  /// The widget the launcher asked to set up, when the app was opened for
  /// that rather than from its icon.
  Future<int?> configuringWidgetId() => _invoke<int>('configuringWidgetId');

  /// Closes the setup screen the launcher opened, keeping the widget.
  Future<void> finishConfiguring() => _invoke<void>('finishConfiguring');

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      // Builds without the native widget code have nothing to update.
      return null;
    } on PlatformException {
      // A widget that cannot be refreshed must not disturb the app.
      return null;
    }
  }
}
