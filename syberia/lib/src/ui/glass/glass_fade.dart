import 'dart:ui' as ui;

/// A blur that lets go smoothly, from full above to nothing below.
///
/// That takes a shader over the blur, which only the Impeller renderer runs.
/// Everywhere else, and wherever the shader fails to load, the edge under
/// the bars is made of bands of blur instead.
abstract final class GlassFade {
  static ui.FragmentProgram? _program;

  /// Whether a blur can let go smoothly.
  static bool get available => _program != null;

  /// Loads the shader. Call once, before the first frame.
  static Future<void> load() async {
    if (_program != null || !ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/glass_fade.frag');
    } on Object {
      // The edge keeps its bands.
    }
  }

  /// A shader for one blur, to be given to [filter]. Null where there is
  /// none.
  static ui.FragmentShader? shader() => _program?.fragmentShader();

  /// The page blurred by [sigma], letting go between [from] and [to]: pixels
  /// from the top of the screen.
  static ui.ImageFilter filter(
    ui.FragmentShader shader, {
    required double sigma,
    required double from,
    required double to,
  }) {
    shader
      ..setFloat(2, from)
      ..setFloat(3, to);
    return ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
  }
}
