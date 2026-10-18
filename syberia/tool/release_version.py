#!/usr/bin/env python3
"""Validate that the release tag, Flutter version and IPA metadata agree."""

import argparse
from pathlib import Path
import plistlib
import re
import zipfile


def read_version(pubspec):
    match = re.search(r"^version:\s*([^\s#]+)", Path(pubspec).read_text(), re.MULTILINE)
    if match is None:
        raise ValueError("pubspec.yaml has no version")
    version = re.fullmatch(r"([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?)\+([1-9][0-9]*)", match[1])
    if version is None:
        raise ValueError("Flutter version must include a version name and a positive build number")
    return version[1], version[2]


def validate(tag, pubspec, ipa=None):
    name, number = read_version(pubspec)
    if tag != "v" + name:
        raise ValueError(f"Release tag {tag} does not match Flutter version v{name}")
    if ipa is not None:
        with zipfile.ZipFile(ipa) as archive:
            info = plistlib.loads(archive.read("Payload/Runner.app/Info.plist"))
        if str(info.get("CFBundleShortVersionString")) != name:
            raise ValueError("IPA version does not match the release tag")
        if str(info.get("CFBundleVersion")) != number:
            raise ValueError("IPA build number does not match pubspec.yaml")
    return name, number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("--pubspec", type=Path, default=Path(__file__).resolve().parents[1] / "pubspec.yaml")
    parser.add_argument("--ipa", type=Path)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    try:
        name, number = validate(args.tag, args.pubspec, args.ipa)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        parser.exit(1, f"Release version check failed: {error}\n")
    if args.github_output is not None:
        with args.github_output.open("a") as output:
            output.write(f"version={name}\nbuild_number={number}\n")
    print(f"Validated {args.tag}, app version {name}, build {number}")


if __name__ == "__main__":
    main()
