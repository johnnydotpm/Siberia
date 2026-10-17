# SiberiaGB branding

The SVG source icons and startup reference were supplied for this project. The HTML is a design reference only; its React runtime and remote font requests are not used by the app.

`lib/src/ui/brand_logo.dart` implements the reference's five-second keyframes, colours, 128-unit icon, 28-unit wordmark spacing and Unbounded typography in Flutter. It loops only while startup is pending, stops when the app is ready, and displays the complete logo without motion when Reduce Motion is enabled.

The Unbounded variable font is bundled under the SIL Open Font License in `assets/fonts/OFL.txt`. Source: https://github.com/google/fonts/tree/main/ofl/unbounded.

To regenerate platform icons and native launch images:

```sh
python3 -m pip install cairosvg Pillow
python3 tool/generate_branding.py
python3 tool/verify_branding.py
```

Android includes adaptive and themed launcher icons and a monochrome notification mark. iOS includes default, dark and tinted app icons plus appearance-aware launch assets. Windows uses a multi-resolution ICO; macOS, Linux and web use the appropriate native icon formats.
