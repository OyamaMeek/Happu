import datetime
import pathlib
import plistlib
import sys
import unittest


app = pathlib.Path(sys.argv.pop(1))
with (app / "Info.plist").open("rb") as source:
    metadata = plistlib.load(source)


class AppMetadataTests(unittest.TestCase):
    def test_happu_identity(self):
        self.assertEqual(metadata["CFBundleDisplayName"], "Happu")
        self.assertEqual(metadata["CFBundleName"], "Happu")
        self.assertEqual(metadata["CFBundleExecutable"], "Happu")
        self.assertTrue((app / "Happu").is_file())
        self.assertEqual(metadata["CFBundleIdentifier"], "com.happu.shureplica")

    def test_compilation_timestamp(self):
        timestamp = metadata.get("HappuBuildTime")
        self.assertIsInstance(timestamp, str)
        compiled = datetime.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        now = datetime.datetime.now(datetime.timezone.utc)
        self.assertEqual(compiled.utcoffset(), datetime.timedelta())
        self.assertLessEqual(compiled, now)
        self.assertLess(now - compiled, datetime.timedelta(hours=1))


unittest.main()
