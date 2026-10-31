import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// One pictogram in both forms the glass design is drawn with: an SF Symbol,
/// which UIKit draws itself, and the closest glyph that Flutter carries for
/// the places where it draws the glass.
@immutable
class GlassSymbol {
  const GlassSymbol(
    this.name,
    this.icon, {
    this.scale = 1,
    this.mirrored = false,
  });

  /// The SF Symbol's name.
  final String name;

  final IconData icon;

  /// How much larger than the others [icon] has to be drawn, and whether it
  /// is flipped, to resemble the SF Symbol where the only glyph Flutter has
  /// is of another make.
  final double scale;
  final bool mirrored;

  /// Shadows that thicken a glyph drawn in [color] by [by] points on every
  /// side: from the regular weight, the only one the Cupertino set comes in,
  /// to the heavier one UIKit gives the symbols in its bars.
  static List<Shadow> heavier(Color color, {double by = 0.12}) => [
    for (final offset in [
      Offset(by, 0),
      Offset(-by, 0),
      Offset(0, by),
      Offset(0, -by),
    ])
      Shadow(color: color, offset: offset),
  ];

  static const house = GlassSymbol('house', CupertinoIcons.house);
  static const houseFill = GlassSymbol('house.fill', CupertinoIcons.house_fill);
  static const calendar = GlassSymbol('calendar', CupertinoIcons.calendar);

  // The Cupertino set has no graduation cap, so Material's stands in. It is
  // smaller, and its tassel hangs on the other side.
  static const graduationCap = GlassSymbol(
    'graduationcap',
    Icons.school_outlined,
    scale: 1.2,
    mirrored: true,
  );
  static const graduationCapFill = GlassSymbol(
    'graduationcap.fill',
    Icons.school,
    scale: 1.2,
    mirrored: true,
  );
  static const envelope = GlassSymbol('envelope', CupertinoIcons.envelope);
  static const envelopeFill = GlassSymbol(
    'envelope.fill',
    CupertinoIcons.envelope_fill,
  );
  static const list = GlassSymbol(
    'list.bullet.rectangle',
    CupertinoIcons.square_list,
  );
  static const listFill = GlassSymbol(
    'list.bullet.rectangle.fill',
    CupertinoIcons.square_list_fill,
  );
  static const book = GlassSymbol('book', CupertinoIcons.book);
  static const bookFill = GlassSymbol('book.fill', CupertinoIcons.book_fill);
  static const checkmark = GlassSymbol(
    'checkmark.square',
    CupertinoIcons.checkmark_square,
  );
  static const checkmarkFill = GlassSymbol(
    'checkmark.square.fill',
    CupertinoIcons.checkmark_square_fill,
  );
  static const megaphone = GlassSymbol('megaphone', CupertinoIcons.speaker_2);
  static const megaphoneFill = GlassSymbol(
    'megaphone.fill',
    CupertinoIcons.speaker_2_fill,
  );
  static const textBubble = GlassSymbol(
    'text.bubble',
    CupertinoIcons.chat_bubble_text,
  );
  static const textBubbleFill = GlassSymbol(
    'text.bubble.fill',
    CupertinoIcons.chat_bubble_text_fill,
  );
  static const menu = GlassSymbol(
    'line.3.horizontal',
    CupertinoIcons.line_horizontal_3,
  );
  static const compose = GlassSymbol(
    'square.and.pencil',
    CupertinoIcons.square_pencil,
  );
  static const sync = GlassSymbol(
    'arrow.triangle.2.circlepath',
    CupertinoIcons.arrow_2_circlepath,
  );
  static const account = GlassSymbol(
    'person.crop.circle',
    CupertinoIcons.person_crop_circle,
  );

  /// Every profile together, where UIKit draws the bar.
  static const together = GlassSymbol(
    'person.2.circle.fill',
    CupertinoIcons.person_2_fill,
  );

  /// A profile's sign where UIKit draws the bar: the first letter of [name]
  /// in a circle. SF Symbols has the letters A to Z, so a Polish letter
  /// stands as its plain form, and any other one as a person.
  static GlassSymbol profile(String name) {
    final trimmed = name.trim();
    final first = trimmed.isEmpty ? '' : trimmed.characters.first.toLowerCase();
    final letter = _plainLetters[first] ?? first;
    return GlassSymbol(
      RegExp(r'^[a-z]$').hasMatch(letter)
          ? '$letter.circle.fill'
          : 'person.crop.circle.fill',
      CupertinoIcons.person_crop_circle_fill,
    );
  }

  static const _plainLetters = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
  };
}

/// A count on a badge: past 99 it says "99+", so the badge stays small.
String badgeText(int count) => count > 99 ? '99+' : '$count';

/// One destination of the glass tab bar.
@immutable
class GlassTab {
  const GlassTab({
    required this.label,
    required this.symbol,
    GlassSymbol? selectedSymbol,
    this.badge = 0,
  }) : selectedSymbol = selectedSymbol ?? symbol;

  final String label;
  final GlassSymbol symbol;
  final GlassSymbol selectedSymbol;

  /// Shown as a badge when positive.
  final int badge;
}

/// One glass button of the top bar.
@immutable
class GlassBarButton {
  const GlassBarButton({
    required this.id,
    required this.symbol,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.prominent = false,
    this.separated = false,
    this.avatar,
    this.tint,
    this.badge = false,
  });

  /// Identifies the button in messages from UIKit, and in tests.
  final String id;
  final GlassSymbol symbol;

  /// Read by screen readers.
  final String label;

  final VoidCallback? onPressed;

  /// Replaces the symbol with the system activity indicator.
  final bool loading;

  /// Fills the glass with the accent colour, for the screen's main action.
  final bool prominent;

  /// Gives the button its own capsule instead of sharing its neighbours'.
  final bool separated;

  /// Drawn instead of the symbol where Flutter draws the bar, as a
  /// profile's initials.
  final Widget? avatar;

  /// The symbol's colour where UIKit draws the bar, instead of the label's.
  final Color? tint;

  /// A dot on the button, for news.
  final bool badge;

  /// Splits [buttons] the way the bar shows them: neighbours share one
  /// capsule, a [separated] button gets its own.
  static List<List<GlassBarButton>> groups(List<GlassBarButton> buttons) {
    final groups = <List<GlassBarButton>>[];
    for (final (index, button) in buttons.indexed) {
      final alone =
          index == 0 || button.separated || buttons[index - 1].separated;
      if (alone) {
        groups.add([button]);
      } else {
        groups.last.add(button);
      }
    }
    return groups;
  }

  /// The width iOS 26 gives a capsule of [count] buttons: a lone button is a
  /// circle, and buttons that share a capsule sit further apart.
  static double groupWidth(int count) =>
      count == 1 ? size : 48 + 56.0 * (count - 1);

  /// Height of every button, and width of a lone one.
  static const double size = 44;

  /// The distance iOS 26 keeps between two capsules.
  static const double groupGap = 12;

  /// The distance iOS 26 keeps between a capsule and the screen's edge.
  static const double edgeGap = 16;
}
