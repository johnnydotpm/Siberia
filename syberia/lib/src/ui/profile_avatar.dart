import 'package:flutter/material.dart';

import '../domain/profiles.dart';

import 'subject_colors.dart';

/// Up to two initials of [name]: the first letters of its first two words
/// that start with a letter, so "Anna · music school" gives "AM".
String profileInitials(String name) {
  final letters = [
    for (final word in name.trim().split(RegExp(r'\s+')))
      if (word.isNotEmpty && RegExp(r'^\p{L}', unicode: true).hasMatch(word))
        word.characters.first.toUpperCase(),
  ];
  return letters.take(2).join();
}

/// A profile's round sign: its initials on its colour, the hue of the
/// subject colours with that index. [news] puts a dot on it, for news the
/// user has not seen.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.name,
    required this.color,
    this.radius = 20,
    this.news = false,
    super.key,
  });

  final String name;
  final int color;
  final double radius;
  final bool news;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = SubjectColors.colors(color, theme.brightness);
    final initials = profileInitials(name);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: palette.background,
      foregroundColor: palette.foreground,
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: radius * 1.2)
          : Text(
              initials,
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: radius * (initials.length > 1 ? 0.72 : 0.9),
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
    );
    if (!news) return avatar;
    final dot = (radius * 0.55).clamp(8.0, 14.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        PositionedDirectional(
          end: -1,
          top: -1,
          child: Container(
            key: const ValueKey('profile-news-dot'),
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// The signs of [profiles] overlapping, each a little to the side of the
/// one before, with a thin gap cut around it: the view of them together.
/// Past three, the third is the number of the rest.
class ProfileStack extends StatelessWidget {
  const ProfileStack(this.profiles, {this.radius = 20, super.key});

  final List<SchoolProfile> profiles;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = profiles.length <= 3 ? profiles : profiles.take(2).toList();
    final rest = profiles.length - shown.length;
    // Far enough apart that the initials of each one show whole.
    final step = radius * 1.6;
    final gap = (radius / 10).clamp(1.5, 2.5);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final signs = <Widget>[
      for (final profile in shown)
        ProfileAvatar(
          name: profile.displayName,
          color: profile.color,
          radius: radius,
        ),
      if (rest > 0)
        CircleAvatar(
          radius: radius,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          child: Text(
            '+$rest',
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: radius * 0.72,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
    ];
    return Semantics(
      label: [for (final profile in profiles) profile.displayName].join(', '),
      excludeSemantics: true,
      child: SizedBox(
        width: 2 * radius + step * (signs.length - 1),
        height: 2 * radius,
        child: Stack(
          children: [
            for (final (index, sign) in signs.indexed)
              PositionedDirectional(
                start: step * index,
                child: index == signs.length - 1
                    ? sign
                    : ClipPath(
                        clipper: _UnderNextSign(
                          radius: radius,
                          next: rtl ? -step : step,
                          gap: gap,
                        ),
                        child: sign,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A round sign without where the next one, [next] to its side, covers it
/// and [gap] around that, so the stack reads on any background.
class _UnderNextSign extends CustomClipper<Path> {
  const _UnderNextSign({
    required this.radius,
    required this.next,
    required this.gap,
  });

  final double radius;
  final double next;
  final double gap;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addOval(Offset.zero & size),
    Path()..addOval(
      Rect.fromCircle(
        center: Offset(size.width / 2 + next, size.height / 2),
        radius: radius + gap,
      ),
    ),
  );

  @override
  bool shouldReclip(_UnderNextSign oldClipper) =>
      oldClipper.radius != radius ||
      oldClipper.next != next ||
      oldClipper.gap != gap;
}
