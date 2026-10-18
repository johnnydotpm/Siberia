import plistlib
from pathlib import Path
import tempfile
import unittest
import zipfile

from release_version import validate


class ReleaseVersionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.pubspec = Path(self.directory.name) / "pubspec.yaml"
        self.pubspec.write_text("name: syberia\nversion: 1.2.0+8\n")
        self.ipa = Path(self.directory.name) / "app.ipa"

    def write_ipa(self, version="1.2.0", build="8"):
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr("Payload/Runner.app/Info.plist", plistlib.dumps({
                "CFBundleShortVersionString": version,
                "CFBundleVersion": build,
            }))

    def test_matching_tag_and_ipa(self):
        self.write_ipa()
        self.assertEqual(validate("v1.2.0", self.pubspec, self.ipa), ("1.2.0", "8"))

    def test_mismatched_tag_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "tag"):
            validate("v1.1.3", self.pubspec)

    def test_mismatched_ipa_version_is_rejected(self):
        self.write_ipa(version="1.1.3")
        with self.assertRaisesRegex(ValueError, "IPA version"):
            validate("v1.2.0", self.pubspec, self.ipa)

    def test_mismatched_ipa_build_is_rejected(self):
        self.write_ipa(build="7")
        with self.assertRaisesRegex(ValueError, "build number"):
            validate("v1.2.0", self.pubspec, self.ipa)


if __name__ == "__main__":
    unittest.main()
