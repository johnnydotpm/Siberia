part of '../app_shell.dart';

/// The sign of what is open: the profile's, or in the view together the
/// signs of every profile in it.
class _OpenProfileSign extends StatelessWidget {
  const _OpenProfileSign(
    this.controller, {
    this.radius = 20,
    this.news = false,
  });

  final AppController controller;
  final double radius;
  final bool news;

  @override
  Widget build(BuildContext context) {
    if (controller.together) {
      return ProfileStack(controller.togetherProfiles, radius: radius);
    }
    final look = controller.profileLook;
    return ProfileAvatar(
      name: look.name,
      color: look.color,
      radius: radius,
      news: news,
    );
  }
}

/// The name of what is open: the profile's, or the view together's.
String _openProfileName(BuildContext context, AppController controller) =>
    controller.together ? context.tr('together') : controller.profileLook.name;

/// Below that name: the school, or the names of the profiles together.
String _openProfileDetail(BuildContext context, AppController controller) =>
    _openProfileDetailOf(controller, together: controller.together);

/// The school of the open profile, or with [together] the names of the
/// profiles in the view together.
String _openProfileDetailOf(
  AppController controller, {
  required bool together,
}) => together
    ? [
        for (final profile in controller.togetherProfiles)
          controller.togetherName(profile),
      ].join(' · ')
    : controller.profileLook.school;

/// Which profile an item of the view together comes from: the profile's
/// name on its colour, kept short. A [dot] is its colour alone, for a tile
/// too small for a name. Nothing outside the view together.
class _ProfileMark extends StatelessWidget {
  const _ProfileMark(this.source, {this.dot = false, this.controller});

  final String? source;
  final bool dot;

  /// The app, for a sheet: it opens above the pages, out of their reach.
  final AppController? controller;

  /// The widest a mark gets, so a long name leaves room for the title.
  static const maxWidth = 112.0;

  @override
  Widget build(BuildContext context) {
    final mark = (controller ?? _ControllerScope.maybeOf(context))?.profileMark(
      source,
    );
    if (mark == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final palette = SubjectColors.colors(mark.color, theme.brightness);
    if (dot) {
      return Semantics(
        label: mark.name,
        child: Container(
          key: const ValueKey('profile-mark-dot'),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    return ConstrainedBox(
      key: const ValueKey('profile-mark'),
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          child: Text(
            mark.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

/// [title] with the mark of the profile [source] after it, in the view
/// together; [title] alone otherwise.
class _MarkedTitle extends StatelessWidget {
  const _MarkedTitle(this.title, this.source, {this.controller});

  final Widget title;
  final String? source;

  /// The app, for a sheet; see [_ProfileMark.controller].
  final AppController? controller;

  @override
  Widget build(BuildContext context) {
    final app = controller ?? _ControllerScope.maybeOf(context);
    if (app?.profileMark(source) == null) return title;
    return Row(
      children: [
        Flexible(child: title),
        const SizedBox(width: 6),
        _ProfileMark(source, controller: app),
      ],
    );
  }
}

/// The mark of the profile [source] at the top of a sheet, above its
/// title, in the view together; nothing otherwise.
class _SheetProfileMark extends StatelessWidget {
  const _SheetProfileMark(this.controller, this.source);

  final AppController controller;
  final String? source;

  @override
  Widget build(BuildContext context) {
    if (controller.profileMark(source) == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _ProfileMark(source, controller: controller),
      ),
    );
  }
}
