#!/usr/bin/env python3
"""Trim the bundled fonts to the characters the app shows.

Run from syberia/ with the original font files, which this overwrites:

    pip install fonttools
    python3 tool/subset_fonts.py path/to/InterVariable.ttf path/to/Unbounded.ttf

Inter keeps Latin with its extensions (Polish), Cyrillic (Russian and
Ukrainian), punctuation, currency, arrows and common symbols. Unbounded only
draws the "SiberiaGB" wordmark, so it keeps basic Latin. Both stay variable
fonts with every weight.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONTS = ROOT / 'assets/fonts'

INTER = ','.join([
    'U+0000-024F', 'U+0259', 'U+02B0-02FF', 'U+0300-036F', 'U+0400-052F',
    'U+1E9E', 'U+2000-206F', 'U+20A0-20CF', 'U+2100-214F', 'U+2150-218F',
    'U+2190-21FF', 'U+2200-22FF', 'U+2300-23FF', 'U+25A0-25FF', 'U+2600-26FF',
    'U+2713-2717', 'U+FB01-FB02', 'U+FEFF', 'U+FFFD',
])
UNBOUNDED = 'U+0020-007E'


def subset(source, target, unicodes, *extra):
    subprocess.run([
        sys.executable, '-m', 'fontTools.subset', str(source),
        f'--unicodes={unicodes}', "--name-IDs=*", "--name-languages=*",
        '--notdef-outline', f'--output-file={target}', *extra,
    ], check=True)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    inter, unbounded = map(Path, sys.argv[1:])
    subset(inter, FONTS / 'InterVariable.ttf', INTER,
           '--layout-features+=tnum,case,frac,sups,subs', '--glyph-names',
           '--symbol-cmap', '--legacy-cmap')
    subset(unbounded, FONTS / 'Unbounded.ttf', UNBOUNDED)
    print('Subset InterVariable.ttf and Unbounded.ttf.')


if __name__ == '__main__':
    main()
