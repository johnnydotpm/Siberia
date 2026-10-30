import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../domain/models.dart';
import '../domain/profiles.dart';
import '../domain/together.dart';
import '../home_widget.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'profile_avatar.dart';

/// The look and content of one home screen widget.
class HomeWidgetSettingsForm extends StatefulWidget {
  const HomeWidgetSettingsForm({
    required this.bridge,
    required this.widgetId,
    required this.onSaved,
    this.profiles = const [],
    this.defaultProfileId,
    super.key,
  });

  final HomeWidgetBridge bridge;
  final int widgetId;
  final VoidCallback onSaved;

  /// The profiles a widget can show, when there is more than one.
  final List<SchoolProfile> profiles;

  /// The profile a widget shows when it has none of its own.
  final String? defaultProfileId;

  @override
  State<HomeWidgetSettingsForm> createState() => _HomeWidgetSettingsFormState();
}

class _HomeWidgetSettingsFormState extends State<HomeWidgetSettingsForm> {
  HomeWidgetConfig? _config;
  bool _dynamicColors = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await widget.bridge.loadConfig(widget.widgetId);
    final dynamicColors = await widget.bridge.dynamicColorsSupported();
    if (mounted) {
      setState(() {
        _config = config;
        _dynamicColors = dynamicColors;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.bridge.saveConfig(widget.widgetId, _config!);
    widget.onSaved();
  }

  /// The profiles in the view together, which a widget can show at once.
  List<SchoolProfile> get _together => [
    for (final profile in widget.profiles)
      if (profile.together) profile,
  ];

  /// Applies [update] to the current settings, so quick taps build on each
  /// other instead of on the settings of the last frame.
  void _change(HomeWidgetConfig Function(HomeWidgetConfig) update) =>
      setState(() => _config = update(_config!));

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final themes = HomeWidgetTheme.values.where(
      (theme) => theme != HomeWidgetTheme.system || _dynamicColors,
    );
    Widget toggle(
      String key,
      bool value,
      HomeWidgetConfig Function(HomeWidgetConfig, bool) update, {
      String? description,
    }) => SwitchListTile.adaptive(
      key: ValueKey('widget-option-$key'),
      title: Text(context.tr(key)),
      subtitle: description == null ? null : Text(context.tr(description)),
      value: value,
      onChanged: (value) => _change((current) => update(current, value)),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            // Scrolls only when the settings do not fit.
            primary: false,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (widget.profiles.length > 1) ...[
                _SectionTitle(context.tr('widgetProfile')),
                if (_together case final together when together.length > 1)
                  ListTile(
                    key: const ValueKey('widget-profile-$togetherId'),
                    leading: ProfileStack(together, radius: 18),
                    title: Text(context.tr('together')),
                    subtitle: Text(
                      [
                        for (final profile in together)
                          togetherName(profile, together),
                      ].join(' · '),
                    ),
                    trailing:
                        (config.profileId ?? widget.defaultProfileId) ==
                            togetherId
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => _change(
                      (current) => current.copyWith(profileId: togetherId),
                    ),
                  ),
                for (final profile in widget.profiles)
                  ListTile(
                    key: ValueKey('widget-profile-${profile.id}'),
                    leading: ProfileAvatar(
                      name: profile.displayName,
                      color: profile.color,
                      radius: 18,
                    ),
                    title: Text(profile.displayName),
                    subtitle: profile.school.isEmpty
                        ? null
                        : Text(profile.school),
                    trailing:
                        (config.profileId ?? widget.defaultProfileId) ==
                            profile.id
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => _change(
                      (current) => current.copyWith(profileId: profile.id),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              _SectionTitle(context.tr('widgetStyle')),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final theme in themes)
                      _ThemeOption(
                        theme: theme,
                        selected: config.theme == theme,
                        onTap: () => _change(
                          (current) => current.copyWith(theme: theme),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _SectionTitle(context.tr('widgetContent')),
              toggle(
                'widgetShowRoom',
                config.showRoom,
                (current, value) => current.copyWith(showRoom: value),
              ),
              toggle(
                'widgetShowTeacher',
                config.showTeacher,
                (current, value) => current.copyWith(showTeacher: value),
              ),
              toggle(
                'widgetShowNextLessons',
                config.showNextLessons,
                (current, value) => current.copyWith(showNextLessons: value),
              ),
              toggle(
                'widgetShowCountdown',
                config.showCountdown,
                (current, value) => current.copyWith(showCountdown: value),
                description: 'widgetShowCountdownDescription',
              ),
              toggle(
                'widgetShowProgress',
                config.showProgress,
                (current, value) => current.copyWith(showProgress: value),
                description: 'widgetShowProgressDescription',
              ),
              toggle(
                'widgetHighlightSubstitutions',
                config.highlightSubstitutions,
                (current, value) =>
                    current.copyWith(highlightSubstitutions: value),
              ),
              toggle(
                'widgetMergeDoubleLessons',
                config.mergeDoubleLessons,
                (current, value) => current.copyWith(mergeDoubleLessons: value),
                description: 'widgetMergeDoubleLessonsDescription',
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('widget-settings-save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _saving ? null : _save,
                child: Text(context.tr('widgetSave')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

/// A small card painted like the widget in [theme].
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final HomeWidgetTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, text) = switch (theme) {
      HomeWidgetTheme.brand => (
        const LinearGradient(colors: [Color(0xFF1E7DA6), Color(0xFF135977)]),
        Colors.white,
      ),
      HomeWidgetTheme.system => (
        LinearGradient(
          colors: [colors.primaryContainer, colors.tertiaryContainer],
        ),
        colors.onPrimaryContainer,
      ),
      HomeWidgetTheme.light => (
        const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFEFF3F5)]),
        const Color(0xFF101416),
      ),
      HomeWidgetTheme.dark => (
        const LinearGradient(colors: [Color(0xFF262C31), Color(0xFF1A1F23)]),
        Colors.white,
      ),
      HomeWidgetTheme.black => (
        const LinearGradient(colors: [Colors.black, Colors.black]),
        Colors.white,
      ),
      HomeWidgetTheme.translucent => (
        const LinearGradient(colors: [Color(0x99000000), Color(0x66000000)]),
        Colors.white,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        key: ValueKey('widget-theme-${theme.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? colors.primary : colors.outlineVariant,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Aa',
                  style: TextStyle(color: text, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('widgetTheme_${theme.name}'),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(fontWeight: selected ? FontWeight.w800 : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The widgets on the Android home screen, each with its settings.
class HomeWidgetsSheet extends StatefulWidget {
  const HomeWidgetsSheet({
    required this.bridge,
    this.profiles = const [],
    this.defaultProfileId,
    super.key,
  });

  final HomeWidgetBridge bridge;
  final List<SchoolProfile> profiles;
  final String? defaultProfileId;

  @override
  State<HomeWidgetsSheet> createState() => _HomeWidgetsSheetState();
}

class _HomeWidgetsSheetState extends State<HomeWidgetsSheet> {
  List<PlacedHomeWidget>? _widgets;
  int? _editing;

  @override
  void initState() {
    super.initState();
    widget.bridge.placedWidgets().then((widgets) {
      if (!mounted) return;
      setState(() {
        _widgets = widgets;
        // With a single widget there is nothing to choose.
        if (widgets.length == 1) _editing = widgets.single.id;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final widgets = _widgets;
    final editing = _editing;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              context.tr('homeWidgets'),
              // Sheet titles are the same across the app.
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: switch ((widgets, editing)) {
              (null, _) => const Center(child: CircularProgressIndicator()),
              (_, final int id) => HomeWidgetSettingsForm(
                bridge: widget.bridge,
                widgetId: id,
                profiles: widget.profiles,
                defaultProfileId: widget.defaultProfileId,
                onSaved: () => Navigator.pop(context),
              ),
              (final List<PlacedHomeWidget> list, _) when list.isEmpty =>
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(context.tr('homeWidgetsNone')),
                ),
              (final List<PlacedHomeWidget> list, _) => ListView(
                // Scrolls only when the widgets do not fit.
                primary: false,
                children: [
                  for (final (index, placed) in list.indexed)
                    ListTile(
                      leading: const Icon(Icons.widgets_rounded),
                      title: Text(
                        context.trArgs('homeWidgetItem', {
                          'number': '${index + 1}',
                        }),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _editing = placed.id),
                    ),
                ],
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Lets the student give long subject names a short one.
class SubjectShortNamesSheet extends StatelessWidget {
  const SubjectShortNamesSheet({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final subjects =
        {
            for (final lesson in controller.snapshot.lessons) lesson.subject,
            for (final grade in controller.snapshot.grades) grade.subject,
          }.where((subject) => subject.trim().isNotEmpty).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              context.tr('shortSubjectNames'),
              // Sheet titles are the same across the app.
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              context.tr('shortSubjectNamesDescription'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: subjects.isEmpty
                ? Center(child: Text(context.tr('noData')))
                : ListView.separated(
                    // Scrolls only when the subjects do not fit.
                    primary: false,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      16 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    itemCount: subjects.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      return TextFormField(
                        key: ValueKey('short-name-$subject'),
                        initialValue: controller.subjectShortNames[subject],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: subject,
                          hintText: context.tr('shortNameHint'),
                        ),
                        onChanged: (value) =>
                            controller.setSubjectShortName(subject, value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// The screen the launcher opens to set up a newly placed Android widget.
class HomeWidgetConfigApp extends StatelessWidget {
  const HomeWidgetConfigApp({
    required this.bridge,
    required this.widgetId,
    this.locale,
    this.colorMode = AppColorMode.system,
    this.profiles = const [],
    this.defaultProfileId,
    super.key,
  });

  final HomeWidgetBridge bridge;
  final int widgetId;
  final Locale? locale;
  final AppColorMode colorMode;
  final List<SchoolProfile> profiles;
  final String? defaultProfileId;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SiberiaGB',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: colorMode == AppColorMode.amoled
        ? AppTheme.amoled()
        : AppTheme.dark(),
    themeMode: switch (colorMode) {
      AppColorMode.system => ThemeMode.system,
      AppColorMode.light => ThemeMode.light,
      AppColorMode.dark || AppColorMode.amoled => ThemeMode.dark,
    },
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('homeWidgets')),
          // Closing keeps the widget with the settings it has.
          leading: CloseButton(onPressed: bridge.finishConfiguring),
        ),
        body: HomeWidgetSettingsForm(
          bridge: bridge,
          widgetId: widgetId,
          profiles: profiles,
          defaultProfileId: defaultProfileId,
          onSaved: bridge.finishConfiguring,
        ),
      ),
    ),
  );
}
