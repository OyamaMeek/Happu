import json
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/release_notes.py"


class ReleaseNotesTests(unittest.TestCase):
    def setUp(self):
        workspace = ROOT / "DerivedData/ReleaseNotesTests"
        workspace.mkdir(parents=True, exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(dir=workspace)
        self.repo = pathlib.Path(self.directory.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Release Test")
        self.git("config", "user.email", "release-test@example.invalid")
        (self.repo / "docs").mkdir()
        (self.repo / "docs/APP_FEATURES.md").write_bytes((ROOT / "docs/APP_FEATURES.md").read_bytes())
        self.commit("feat: 首次发布应用", "Happu/change.txt")
        self.ipa = self.repo / "Happu.ipa"
        self.metadata = {"HappuBuildTime": "2026-10-05T08:44:15Z"}
        self.write_ipa()
        self.releases = self.repo / "releases.json"
        self.write_releases([])

    def tearDown(self):
        self.directory.cleanup()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True).strip()

    def commit(self, subject, path):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(subject, encoding="utf-8")
        self.git("add", path)
        self.git("commit", "-q", "-m", subject)

    def write_ipa(self):
        with zipfile.ZipFile(self.ipa, "w") as archive:
            archive.writestr("Payload/Happu.app/Info.plist", plistlib.dumps(self.metadata))

    def write_releases(self, releases):
        self.releases.write_text(json.dumps([releases]), encoding="utf-8")

    def notes(self):
        self.assertTrue(SCRIPT.is_file(), "缺少 Release 介绍生成器")
        return subprocess.check_output(
            [sys.executable, str(SCRIPT), str(self.ipa), "--releases", str(self.releases)], cwd=self.repo, text=True, encoding="utf-8",
        )

    def test_first_release_sections_and_real_build_time(self):
        result = self.notes()
        self.assertEqual(result.count("## "), 3)
        for heading in ("App 主要功能", "本次更新内容", "编译时间"):
            self.assertIn("## " + heading, result)
        self.assertIn("首次发布 Happu", result)
        self.assertIn("2026-10-05 16:44:15", result)
        self.assertNotIn("\ufffd", result)

    def test_changes_since_previous_release_exclude_docs(self):
        self.git("tag", "v0.0.1")
        self.write_releases([{"tag_name": "v0.0.1", "draft": False, "prerelease": False}])
        self.commit("docs: 保存历史日志", "docs/CHANGELOG.md")
        self.commit("fix: 修复文件分享", "Happu/change.txt")
        self.git("tag", "-a", "v0.0.2", "-m", "Happu 0.0.2")
        result = self.notes()
        self.assertIn("- 修复文件分享", result)
        self.assertNotIn("保存历史日志", result)
        self.assertNotIn("首次发布 Happu", result)

    def test_missing_build_time_fails_without_output(self):
        self.metadata.clear()
        self.write_ipa()
        self.assertTrue(SCRIPT.is_file(), "缺少 Release 介绍生成器")
        result = subprocess.run([sys.executable, str(SCRIPT), str(self.ipa), "--releases", str(self.releases)], cwd=self.repo, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("HappuBuildTime", result.stderr)

    def test_failed_draft_does_not_hide_unpublished_changes(self):
        self.git("tag", "v0.0.1")
        self.commit("feat: 增加目录上传", "Happu/change.txt")
        self.git("tag", "v0.0.2")
        self.commit("fix: 修复上传名称", "Happu/change.txt")
        self.write_releases([
            {"tag_name": "v0.0.1", "draft": False, "prerelease": False},
            {"tag_name": "v0.0.2", "draft": True, "prerelease": False},
        ])
        result = self.notes()
        self.assertIn("- 增加目录上传", result)
        self.assertIn("- 修复上传名称", result)

    def test_historical_ref_and_utf8_output_file(self):
        self.git("tag", "v0.0.1")
        self.commit("fix: 修复文件分享", "Happu/change.txt")
        self.git("tag", "v0.0.2")
        self.commit("feat: 新增后续功能", "Happu/change.txt")
        self.write_releases([{"tag_name": "v0.0.1", "draft": False, "prerelease": False}])
        output = self.repo / "介绍.md"
        subprocess.run([
            sys.executable, str(SCRIPT), str(self.ipa), "--releases", str(self.releases),
            "--ref", "v0.0.2", "--output", str(output),
        ], cwd=self.repo, check=True)
        result = output.read_text(encoding="utf-8")
        self.assertIn("- 修复文件分享", result)
        self.assertNotIn("新增后续功能", result)
        self.assertNotIn("\ufffd", result)


if __name__ == "__main__":
    unittest.main()
