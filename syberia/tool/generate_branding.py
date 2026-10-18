#!/usr/bin/env python3
"""Render the supplied SVGs into platform assets (pip install cairosvg Pillow)."""
import io
import json
from pathlib import Path
import xml.etree.ElementTree as ET

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / 'assets/branding'
SOURCE = BRAND / 'source'
ANDROID = ROOT / 'android/app/src/main/res'
IOS = ROOT / 'ios/Runner/Assets.xcassets'


def svg(name):
    return (SOURCE / f'siberiagb-{name}.svg').read_text()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data)


def render(source, target, size, opaque=False):
    target.parent.mkdir(parents=True, exist_ok=True)
    png = cairosvg.svg2png(bytestring=source.encode(), output_width=size, output_height=size)
    image = Image.open(io.BytesIO(png))
    if opaque:
        image = image.convert('RGB')
    image.save(target)
    return image


def vector(name):
    root = ET.fromstring(svg(name))
    paths = []
    for path in root.iter('{http://www.w3.org/2000/svg}path'):
        alpha = path.get('fill-opacity', '1')
        fill = path.get('fill', '#000000')
        if fill == '#000':
            fill = '#000000'
        paths.append(f'    <path android:fillColor="{fill}" android:fillAlpha="{alpha}" android:pathData="{path.attrib["d"]}"/>')
    return '\n'.join([
        '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="200" android:viewportHeight="200">',
        '  <group android:scaleX="0.72" android:scaleY="0.72" android:translateX="28" android:translateY="34.48">',
        *paths, '  </group>', '</vector>', '',
    ])


for theme in ['light', 'dark']:
    full = svg(f'icon-{theme}')
    rounded = full.replace('<rect width="200" height="200"', '<rect rx="45" width="200" height="200"')
    render(rounded, BRAND / f'logo-{theme}.png', 512)
    render(full, BRAND / f'app-icon-{theme}.png', 1024, True)
    for scale in [1, 2, 3]:
        suffix = '' if scale == 1 else f'@{scale}x'
        variant = '' if theme == 'light' else '-dark'
        render(rounded, IOS / f'LaunchImage.imageset/LaunchImage{variant}{suffix}.png', 112 * scale)
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        mode = '' if theme == 'light' else '-night'
        render(svg(f'icon-{theme}-small') if size <= 72 else full,
               ANDROID / f'mipmap{mode}-{density}/ic_launcher.png', size, True)
        render(rounded, ANDROID / f'drawable{mode}-{density}/launch_logo.png', round(size / 48 * 112))
    mode = '' if theme == 'light' else '-night'
    write(ANDROID / f'drawable{mode}/app_icon_foreground.xml', vector(f'foreground-{theme}'))
    bg = '#E3EEF2' if theme == 'light' else '#0C1C27'
    launch = '#FFFFFF' if theme == 'light' else '#0B1A22'
    write(ANDROID / f'values{mode}/branding_colors.xml',
          f'<resources><color name="app_icon_background">{bg}</color><color name="launch_background_color">{launch}</color></resources>\n')

write(ANDROID / 'drawable/app_icon_monochrome.xml', vector('monochrome'))
write(ANDROID / 'drawable/ic_notification.xml', vector('monochrome').replace('#000000', '#FFFFFF'))
for api in [26, 33]:
    mono = '\n  <monochrome android:drawable="@drawable/app_icon_monochrome"/>' if api >= 33 else ''
    write(ANDROID / f'mipmap-anydpi-v{api}/ic_launcher.xml',
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '  <background android:drawable="@color/app_icon_background"/>\n'
          '  <foreground android:drawable="@drawable/app_icon_foreground"/>' + mono + '\n</adaptive-icon>\n')
for folder in ['drawable', 'drawable-v21']:
    write(ANDROID / folder / 'launch_background.xml',
          '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '  <item android:drawable="@color/launch_background_color"/>\n'
          '  <item android:gravity="center" android:width="112dp" android:height="112dp">\n'
          '    <bitmap android:gravity="fill" android:src="@drawable/launch_logo"/>\n'
          '  </item>\n</layer-list>\n')
for mode, parent in [('', 'Theme.Light.NoTitleBar'), ('-night', 'Theme.Black.NoTitleBar')]:
    write(ANDROID / f'values{mode}-v31/styles.xml', f'''<resources>
  <style name="LaunchTheme" parent="@android:style/{parent}">
    <item name="android:windowSplashScreenBackground">@color/launch_background_color</item>
    <item name="android:windowSplashScreenAnimatedIcon">@drawable/app_icon_foreground</item>
    <item name="android:windowSplashScreenIconBackgroundColor">@color/app_icon_background</item>
    <item name="android:windowLightStatusBar">{'true' if not mode else 'false'}</item>
  </style>
</resources>
''')

# Keep legacy image filenames current as well as the modern iOS variants.
iconset = IOS / 'AppIcon.appiconset'
for file in iconset.glob('Icon-App-*.png'):
    with Image.open(file) as old:
        size = old.width
    render(svg('icon-light-small') if size <= 60 else svg('icon-light'), file, size, True)
images = []
for theme in ['light', 'dark', 'tinted']:
    filename = f'AppIcon-{theme}.png'
    # Tinted app icons have an opaque grayscale background; iOS supplies tint.
    if theme == 'tinted':
        image = Image.open(BRAND / 'app-icon-dark.png').convert('L').convert('RGB')
        image.save(iconset / filename)
    else:
        render(svg(f'icon-{theme}'), iconset / filename, 1024, True)
    item = {'filename': filename, 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}
    if theme != 'light':
        item['appearances'] = [{'appearance': 'luminosity', 'value': theme}]
    images.append(item)
write(iconset / 'Contents.json', json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
images = []
for theme in ['light', 'dark']:
    for scale in [1, 2, 3]:
        suffix = '' if scale == 1 else f'@{scale}x'
        variant = '' if theme == 'light' else '-dark'
        item = {'idiom': 'universal', 'filename': f'LaunchImage{variant}{suffix}.png', 'scale': f'{scale}x'}
        if theme == 'dark':
            item['appearances'] = [{'appearance': 'luminosity', 'value': 'dark'}]
        images.append(item)
write(IOS / 'LaunchImage.imageset/Contents.json', json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
write(IOS / 'LaunchBackground.colorset/Contents.json', json.dumps({
    'colors': [
        {'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {'red': '1.000', 'green': '1.000', 'blue': '1.000', 'alpha': '1.000'}}},
        {'idiom': 'universal', 'appearances': [{'appearance': 'luminosity', 'value': 'dark'}],
         'color': {'color-space': 'srgb', 'components': {'red': '0.043', 'green': '0.102', 'blue': '0.133', 'alpha': '1.000'}}},
    ], 'info': {'author': 'xcode', 'version': 1},
}, indent=2) + '\n')
render(svg('icon-light'), ROOT / 'linux/packaging/app.syberia.client.png', 256, True)
windows = Image.open(BRAND / 'app-icon-light.png')
windows.save(ROOT / 'windows/runner/resources/app_icon.ico', sizes=[(size, size) for size in [16, 24, 32, 48, 64, 128, 256]])
print('Rendered branding assets for Flutter, Android, iOS, Windows and Linux.')
