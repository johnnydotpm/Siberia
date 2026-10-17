import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The hairline at the very edge of a piece of glass.
@immutable
class GlassRim {
  /// A hairline of one [color] all the way round.
  const GlassRim.even(this.color, {this.softness = 0.35})
    : lit = false,
      blendMode = BlendMode.srcOver;

  /// The glint of a light at the upper left, the way iOS 26 puts it on its
  /// bars: [color] in full where the edge faces that light or faces away
  /// from it, less as the edge turns, and nothing where it runs along the
  /// light, at the upper right and the lower left.
  const GlassRim.lit(
    this.color, {
    this.blendMode = BlendMode.srcOver,
    this.softness = 0.35,
  }) : lit = true;

  final Color color;
  final bool lit;

  /// How the hairline goes over the glass. Light that the glass throws back
  /// is added to it, which leaves bright glass with a white edge and dark
  /// glass with a faint one.
  final BlendMode blendMode;

  /// How gently the hairline fades towards the inside of the glass, as the
  /// sigma of a blur in points.
  final double softness;

  GlassRim faded(double show) {
    final color = this.color.withValues(alpha: this.color.a * show);
    return lit
        ? GlassRim.lit(color, blendMode: blendMode, softness: softness)
        : GlassRim.even(color, softness: softness);
  }

  @override
  bool operator ==(Object other) =>
      other is GlassRim &&
      other.color == color &&
      other.lit == lit &&
      other.blendMode == blendMode &&
      other.softness == softness;

  @override
  int get hashCode => Object.hash(color, lit, blendMode, softness);
}

/// What one kind of glass does to the page behind it and how its edge looks.
///
/// Measured on iOS 26, Apple's Liquid Glass shows the page under a bar or a
/// panel blurred a little and with its colours remapped: contrast pressed
/// flat, colours made richer, and everything lifted towards white or, in the
/// dark appearance, held near black. [tone] is that remapping.
@immutable
class GlassLook {
  /// Glass that blurs the page by [blur] and remaps its colours with [tone].
  const GlassLook({
    required this.blur,
    required this.tone,
    required this.rim,
    this.bend = 0,
    this.fold = 1,
    this.shadows = const [],
    this.visibility = 1,
  }) : veil = null;

  /// Glass that only lays [veil] over the page, like glass filled with a
  /// colour. It takes no reading of the page, so it is plain paint. With
  /// [bend], its rim bends the veil together with what lies on the glass.
  const GlassLook.veiled(
    Color this.veil, {
    required this.rim,
    this.bend = 0,
    this.fold = 1,
    this.shadows = const [],
    this.visibility = 1,
  }) : blur = 0,
       tone = _identity;

  /// Glass that keeps [gain] of the page's contrast after making its colours
  /// [saturation] times as rich, and adds [lift] to every channel, counted
  /// in steps of 255.
  factory GlassLook.regular({
    required double blur,
    required double saturation,
    required double gain,
    required double lift,
    required GlassRim rim,
    double bend = 0,
    List<BoxShadow> shadows = const [],
  }) {
    // Saturation moves every colour away from its own grey (Rec. 709 luma).
    const lumaR = 0.2126, lumaG = 0.7152, lumaB = 0.0722;
    final grey = gain * (1 - saturation);
    final own = gain * saturation;
    return GlassLook(
      blur: blur,
      tone: [
        grey * lumaR + own, grey * lumaG, grey * lumaB, lift, //
        grey * lumaR, grey * lumaG + own, grey * lumaB, lift, //
        grey * lumaR, grey * lumaG, grey * lumaB + own, lift,
      ],
      rim: rim,
      bend: bend,
      shadows: shadows,
    );
  }

  static const _identity = <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0];

  /// How far the page is blurred, as the sigma of a Gaussian in points.
  final double blur;

  /// Three rows, for the red, green and blue that show through the glass.
  /// Each holds what it takes of the page's red, green and blue, and what is
  /// added, counted in steps of 255.
  final List<double> tone;

  /// The colour laid over the page by glass that does nothing else.
  final Color? veil;

  final GlassRim rim;

  /// How many points in from its edge the glass bends what shows through it,
  /// where the renderer can do that: the rim is a lens. Zero for glass that
  /// is flat to the edge.
  final double bend;

  /// How far towards its middle the very edge of the glass reaches for what
  /// it shows, from 0 to 1. Apple's bars and panels reach all the way, which
  /// mirrors the picture in the rim.
  final double fold;

  /// Shadows cast outside the glass. Nothing of them shows through it.
  final List<BoxShadow> shadows;

  /// How far the glass has appeared, from 0 to 1. See [faded].
  final double visibility;

  /// The look this one has when it is [visibility] of the way to appearing
  /// out of nothing.
  GlassLook faded(double visibility) {
    if (visibility >= 1) return this;
    final show = visibility.clamp(0.0, 1.0);
    final rim = this.rim.faded(show);
    final shadows = [
      for (final shadow in this.shadows)
        shadow.copyWith(
          color: shadow.color.withValues(alpha: shadow.color.a * show),
        ),
    ];
    final veil = this.veil;
    if (veil != null) {
      return GlassLook.veiled(
        veil.withValues(alpha: veil.a * show),
        rim: rim,
        bend: bend,
        fold: fold,
        shadows: shadows,
        visibility: this.visibility * show,
      );
    }
    return GlassLook(
      blur: blur * show,
      tone: [
        for (var index = 0; index < 12; index++)
          ui.lerpDouble(_identity[index], tone[index], show)!,
      ],
      rim: rim,
      // The lens stays and bends less: see [visibility].
      bend: bend,
      fold: fold,
      shadows: shadows,
      visibility: this.visibility * show,
    );
  }

  /// The filter that turns the page behind the glass into what shows
  /// through it.
  ui.ImageFilter get filter {
    final colour = ColorFilter.matrix([
      tone[0], tone[1], tone[2], 0, tone[3], //
      tone[4], tone[5], tone[6], 0, tone[7], //
      tone[8], tone[9], tone[10], 0, tone[11], //
      0, 0, 0, 1, 0,
    ]);
    if (blur <= 0) return colour;
    return ui.ImageFilter.compose(
      outer: colour,
      inner: ui.ImageFilter.blur(
        sigmaX: blur,
        sigmaY: blur,
        // At the screen's edge the blur has to make up what lies beyond it.
        tileMode: TileMode.mirror,
      ),
    );
  }
}

/// The glass Flutter draws where the system has none of its own.
///
/// Every drawn surface takes its look from here, so the bars, the buttons and
/// the panels are made of the same material. The numbers were read off
/// screenshots of UIKit's glass on iOS 26 over this app's own pages, and
/// reproduce its colours there to within a step or two of 255.
abstract final class GlassMaterial {
  /// The colour of symbols and labels on the glass: iOS draws them black on
  /// its light material and just short of white on the dark one.
  static Color label(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFFF3F3F4)
      : const Color(0xFF000000);

  /// The soft shadow iOS gives light glass, a little stronger below it than
  /// above. Its dark glass casts none.
  static const _shadows = [
    BoxShadow(color: Color(0x19000000), blurRadius: 28, offset: Offset(0, 8)),
  ];

  /// The glint on the edge of a bar or a button: a cool white light added to
  /// the glass, about 35 steps of 255 at its strongest. On the light
  /// material, where that turns the edge white, iOS keeps it crisp.
  static const _glint = GlassRim.lit(
    Color(0x30D1F4FD),
    blendMode: BlendMode.plus,
  );
  static const _crispGlint = GlassRim.lit(
    Color(0x30D1F4FD),
    blendMode: BlendMode.plus,
    softness: 0.12,
  );

  /// How far from its edge the glass of a bar bends what shows through it.
  static const double _bend = 14;

  /// The glass of the tab bar.
  static GlassLook chrome(Brightness brightness) =>
      brightness == Brightness.dark ? _chromeDark : _chromeLight;

  static final _chromeLight = GlassLook.regular(
    blur: 2.4,
    saturation: 2.85,
    gain: 0.246,
    lift: 189.4,
    rim: _crispGlint,
    bend: _bend,
    shadows: _shadows,
  );

  static final _chromeDark = GlassLook.regular(
    blur: 2.4,
    saturation: 1.94,
    gain: 0.352,
    lift: 17.2,
    rim: _glint,
    bend: _bend,
  );

  /// The glass of the buttons in the top bar. On the light material iOS
  /// makes it a shade lighter than the tab bar's. Its edge is left flat:
  /// under these buttons the page is blurred away, with nothing to bend.
  static GlassLook button(Brightness brightness) =>
      brightness == Brightness.dark ? _buttonDark : _buttonLight;

  static final _buttonLight = GlassLook.regular(
    blur: 2.4,
    saturation: 2.85,
    gain: 0.246,
    lift: 191.3,
    rim: _crispGlint,
    shadows: _shadows,
  );

  static final _buttonDark = GlassLook.regular(
    blur: 2.4,
    saturation: 1.94,
    gain: 0.352,
    lift: 17.2,
    rim: _glint,
  );

  /// The glass of the button for a screen's main action: [accent] itself.
  /// The glint on its edge is the accent turned light and towards cyan,
  /// which is what iOS makes of this app's blue.
  static GlassLook prominent(Brightness brightness, Color accent) {
    final hsv = HSVColor.fromColor(accent);
    final glint = hsv
        .withHue((hsv.hue - 19) % 360)
        .withSaturation(0.447)
        .withValue(1)
        .toColor();
    return GlassLook.veiled(
      accent,
      rim: GlassRim.lit(glint, softness: 0.15),
      shadows: brightness == Brightness.dark ? const [] : _shadows,
    );
  }

  /// The glass of a panel that holds text: a sheet, a dialog or the side
  /// menu. It blurs the page further than a bar does and lets less of it
  /// through, so the text on it stays readable over anything. Its cast of
  /// blue is what iOS makes of the app's surface colour as the tint of its
  /// glass. Its rim bends the page over a wider band than a bar's.
  static GlassLook panel(Brightness brightness) =>
      brightness == Brightness.dark ? _panelDark : _panelLight;

  static const _panelLight = GlassLook(
    blur: 6,
    tone: [
      0.2274, 0.0293, -0.0130, 183.6, //
      -0.0082, 0.2014, -0.0127, 202.6, //
      -0.0311, -0.0674, 0.2047, 224.3,
    ],
    rim: GlassRim.even(Color(0xF2F5FFFF)),
    bend: 24,
    shadows: _shadows,
  );

  static const _panelDark = GlassLook(
    blur: 6,
    tone: [
      0.1665, -0.0490, -0.0155, 17.9, //
      -0.0154, 0.1237, -0.0049, 20.4, //
      -0.0233, -0.0381, 0.1813, 22.8,
    ],
    rim: GlassRim.even(Color(0x3AB3D9FF)),
    bend: 24,
  );

  /// The selection of the tab bar while it is held: a clearer, brighter
  /// piece of glass floating over the bar. Its rim stretches the tabs it
  /// passes over. It does not mirror them as the bar's rim does the page:
  /// the tabs are sharp, and a mirror image squeezed into the rim would be a
  /// tangle of thin lines.
  static GlassLook lens(Brightness brightness) => brightness == Brightness.dark
      ? const GlassLook.veiled(
          Color(0x24FFFFFF),
          rim: _glint,
          bend: 10,
          fold: 0.1,
        )
      : const GlassLook.veiled(
          Color(0x80FFFFFF),
          rim: _crispGlint,
          bend: 10,
          fold: 0.1,
          shadows: _shadows,
        );
}
