import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/release_version.py"


class ReleaseVersionTests(unittest.TestCase):
    def setUp(self):
        workspace = ROOT / "DerivedData/ReleaseTests"
        workspace.mkdir(parents=True, exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(dir=workspace)
        self.repo = pathlib.Path(self.directory.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release-test@example.invalid")
        self.commit()

    def tearDown(self):
        self.directory.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True).strip()

    def commit(self):
        self.git("commit", "-q", "--allow-empty", "-m", "test: release input")

    def version(self):
        self.assertTrue(SCRIPT.is_file(), "缺少自动 Release 版本分配脚本")
        return subprocess.check_output([sys.executable, str(SCRIPT)], cwd=self.repo, text=True).strip()

    def test_first_version(self):
        self.assertEqual(self.version(), "v0.0.1")

    def test_numeric_patch_increment(self):
        for tag in ("v0.0.2", "v0.0.9", "v0.0.10"):
            self.git("tag", tag)
        self.commit()
        self.assertEqual(self.version(), "v0.0.11")

    def test_ignore_unrelated_and_prerelease_tags(self):
        for tag in ("snapshot", "v9.0.0-beta", "v01.0.0"):
            self.git("tag", tag)
        self.assertEqual(self.version(), "v0.0.1")

    def test_reuse_existing_commit_version(self):
        self.git("tag", "v0.0.1")
        self.assertEqual(self.version(), "v0.0.1")

    def test_reuse_annotated_tag(self):
        self.git("tag", "-a", "v0.0.3", "-m", "Happu 0.0.3")
        self.assertEqual(self.version(), "v0.0.3")

    def test_increment_highest_major_and_minor(self):
        self.git("tag", "v1.2.9")
        self.git("tag", "v0.9.99")
        self.commit()
        self.assertEqual(self.version(), "v1.2.10")

    def test_missing_repository_fails(self):
        directory = self.repo / "outside"
        directory.mkdir()
        result = subprocess.run(
            [sys.executable, str(SCRIPT)], cwd=directory, text=True, capture_output=True,
            env={**os.environ, "GIT_CEILING_DIRECTORIES": str(self.repo)},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("not a git repository", result.stderr)

    def test_old_retry_does_not_replace_latest(self):
        self.git("tag", "v0.0.1")
        releases = self.repo / "releases.json"
        releases.write_text(json.dumps([[{
            "tag_name": "v0.0.2", "draft": False, "prerelease": False,
        }]]))
        result = subprocess.check_output(
            [sys.executable, str(SCRIPT), "--latest", str(releases)], cwd=self.repo, text=True,
        ).strip()
        self.assertEqual(result, "false")

    def test_latest_ignores_drafts_and_prereleases(self):
        self.git("tag", "v0.0.10")
        releases = self.repo / "releases.json"
        releases.write_text(json.dumps([[
            {"tag_name": "v0.0.9", "draft": False, "prerelease": False},
            {"tag_name": "v0.0.11", "draft": True, "prerelease": False},
            {"tag_name": "v0.0.12-beta", "draft": False, "prerelease": True},
        ]]))
        result = subprocess.check_output(
            [sys.executable, str(SCRIPT), "--latest", str(releases)], cwd=self.repo, text=True,
        ).strip()
        self.assertEqual(result, "true")


if __name__ == "__main__":
    unittest.main()
