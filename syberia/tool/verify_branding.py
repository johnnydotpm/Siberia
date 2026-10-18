#!/usr/bin/env python3
"""Validate native icon catalogs and launch resources without extra packages."""
import json
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / 'android/app/src/main/res'


def png(path, expected, opaque=False):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    width, height, _, color = struct.unpack('>IIBB', data[16:26])
    assert (width, height) == (expected, expected), (path, width, height)
    assert not opaque or color == 2, f'iOS app icons must be opaque RGB: {path}'


def main():
    ios = ROOT / 'ios/Runner/Assets.xcassets'
    for catalog in ios.glob('*.appiconset'):
        images = json.loads((catalog / 'Contents.json').read_text())['images']
        for image in images:
            size = float(image['size'].split('x')[0]) * float(image.get('scale', '1x')[:-1])
            png(catalog / image['filename'], int(size), opaque=True)
    for image in json.loads((ios / 'LaunchImage.imageset/Contents.json').read_text())['images']:
        png(ios / 'LaunchImage.imageset' / image['filename'], 112 * int(image['scale'][0]))
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
        for mode in ['', '-night']:
            png(ANDROID / f'mipmap{mode}-{density}/ic_launcher.png', size)
    png(ROOT / 'linux/packaging/app.syberia.client.png', 256)
    data = (ROOT / 'windows/runner/resources/app_icon.ico').read_bytes()
    reserved, kind, count = struct.unpack('<HHH', data[:6])
    assert (reserved, kind) == (0, 1) and count >= 6, 'Windows icon lacks multiple resolutions'
    for xml in ANDROID.rglob('*.xml'):
        ET.parse(xml)
    for catalog in ios.glob('*.colorset'):
        json.loads((catalog / 'Contents.json').read_text())
    ET.parse(ROOT / 'ios/Runner/Base.lproj/LaunchScreen.storyboard')
    print('Branding checks passed: icon dimensions, iOS opacity, launch images, Windows ICO and native XML.')


if __name__ == '__main__':
    main()
