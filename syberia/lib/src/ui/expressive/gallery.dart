import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/expressive_tokens.dart';
import '../../theme/wallpaper_colors.dart';
import 'button_groups.dart';
import 'loading_indicator.dart';
import 'motion.dart';
import 'navigation_bar.dart';
import 'shapes.dart';
import 'wavy_progress.dart';

/// Every Expressive component on one page, live, in the Expressive theme
/// whatever the app's design: opened from the debug menu to try them on a
/// phone before the screens use them.
class ExpressiveGallery extends StatefulWidget {
  const ExpressiveGallery({this.wallpaper, super.key});

  /// The wallpaper's colours, when the app takes them.
  final WallpaperColors? wallpaper;

  @override
  State<ExpressiveGallery> createState() => _ExpressiveGalleryState();
}

class _ExpressiveGalleryState extends State<ExpressiveGallery> {
  double _progress = 0.62;
  String _day = 'pt';
  String _period = 'sem1';
  bool _menuOpen = false;
  bool _switch = true;
  int _shape = 0;
  int _tab = 0;

  static final _shapes = [
    ExpressiveShapes.cookie9,
    ExpressiveShapes.softBurst,
    ExpressiveShapes.sunny,
    ExpressiveShapes.pentagon,
    ExpressiveShapes.cookie4,
    ExpressiveShapes.pill,
    ExpressiveShapes.oval,
  ];
  static final _morphSpring = SpringCurve(Springs.defaultSpatial);

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    unawaited(AppTheme.loadExpressiveFont());
    final theme = AppTheme.expressive(
      brightness,
      wallpaper: widget.wallpaper,
      latinFont: AppTheme.expressiveFontDraws(Localizations.localeOf(context)),
    );
    return Theme(
      data: theme,
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final emphasized = ExpressiveType.of(context);
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: Space.extraLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall!.copyWith(color: colors.primary),
          ),
          const SizedBox(height: Space.small),
          ...children,
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Expressive components')),
      body: ListView(
        key: const ValueKey('expressive-gallery'),
        padding: const EdgeInsets.all(Space.large),
        children: [
          Text('Expressive', style: emphasized.displayMedium),
          const SizedBox(height: Space.large),
          section('Loading indicator', [
            const Row(
              children: [
                LoadingIndicator(),
                SizedBox(width: Space.large),
                LoadingIndicator(contained: true),
              ],
            ),
          ]),
          section('Wavy progress', [
            WavyProgressIndicator(
              key: const ValueKey('gallery-wavy'),
              value: _progress,
            ),
            Slider(
              value: _progress,
              onChanged: (value) => setState(() => _progress = value),
            ),
            Container(
              padding: const EdgeInsets.all(Space.large),
              decoration: ShapeDecoration(
                color: colors.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Corners.extraLarge),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Matematyka',
                    style: theme.textTheme.headlineMedium!.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: Space.medium),
                  // On a coloured card the track takes the screen's colour.
                  WavyProgressIndicator(
                    value: _progress,
                    trackColor: colors.surface,
                  ),
                ],
              ),
            ),
          ]),
          section('Connected button group', [
            ConnectedButtonGroup<String>(
              key: const ValueKey('gallery-days'),
              selected: _day,
              onSelected: (day) => setState(() => _day = day),
              options: [
                for (final (value, label) in const [
                  ('pn', 'pn 2'),
                  ('wt', 'wt 3'),
                  ('sr', 'śr 4'),
                  ('cz', 'czw 5'),
                  ('pt', 'pt 6'),
                ])
                  (
                    value: value,
                    label: label,
                    icon: null,
                    key: ValueKey('gallery-day-$value'),
                  ),
              ],
            ),
            const SizedBox(height: Space.medium),
            ConnectedButtonGroup<String>(
              selected: _period,
              onSelected: (period) => setState(() => _period = period),
              options: const [
                (value: 'sem1', label: 'Semestr 1', icon: null, key: null),
                (value: 'sem2', label: 'Semestr 2', icon: null, key: null),
                (value: 'year', label: 'Rok', icon: null, key: null),
              ],
            ),
          ]),
          section('Split button', [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SplitButton(
                key: const ValueKey('gallery-split'),
                label: 'Ważona',
                menuTooltip: 'Average',
                menuOpen: _menuOpen,
                onPressed: () {},
                onMenu: () => setState(() => _menuOpen = !_menuOpen),
              ),
            ),
          ]),
          section('Shapes (tap the big one)', [
            Wrap(
              spacing: Space.small,
              runSpacing: Space.small,
              children: [
                for (final (index, shape) in _shapes.indexed)
                  ShapeBadge(
                    shape: shape,
                    size: 48,
                    color: colors.tertiary,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.titleLarge!.copyWith(
                        color: colors.onTertiary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.medium),
            Center(
              child: GestureDetector(
                key: const ValueKey('gallery-morph'),
                onTap: () =>
                    setState(() => _shape = (_shape + 1) % _shapes.length),
                child: AnimatedContainer(
                  width: 112,
                  height: 112,
                  duration: _morphSpring.duration,
                  curve: _morphSpring,
                  decoration: ShapeDecoration(
                    color: colors.primary,
                    shape: _shapes[_shape],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '4,62',
                    style: theme.textTheme.headlineLarge!.copyWith(
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ]),
          section('Switch', [
            SwitchListTile(
              key: const ValueKey('gallery-switch'),
              title: const Text('Wallpaper colours'),
              value: _switch,
              onChanged: (value) => setState(() => _switch = value),
            ),
          ]),
        ],
      ),
      bottomNavigationBar: ExpressiveNavigationBar(
        selectedIndex: _tab,
        onSelected: (tab) => setState(() => _tab = tab),
        destinations: [
          for (final (icon, label, badge) in const [
            (Icons.home_outlined, 'Today', 0),
            (Icons.calendar_view_week_outlined, 'Timetable', 0),
            (Icons.school_outlined, 'Grades', 0),
            (Icons.mail_outline_rounded, 'Messages', 3),
          ])
            (icon: icon, label: label, badge: badge, badgeText: '$badge'),
        ],
      ),
    );
  }
}
