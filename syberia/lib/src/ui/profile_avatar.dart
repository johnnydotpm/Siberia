import 'package:flutter/material.dart';

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
