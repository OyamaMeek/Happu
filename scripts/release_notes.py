import argparse
import datetime
import json
import pathlib
import plistlib
import re
import subprocess
import zipfile


def git(*args):
    return subprocess.check_output(["git", *args], text=True, encoding="utf-8").strip()


parser = argparse.ArgumentParser()
parser.add_argument("ipa", type=pathlib.Path)
parser.add_argument("--releases", type=pathlib.Path, required=True)
parser.add_argument("--ref", default="HEAD")
parser.add_argument("--output", type=pathlib.Path)
args = parser.parse_args()
with zipfile.ZipFile(args.ipa) as archive:
    metadata = plistlib.loads(archive.read("Payload/Happu.app/Info.plist"))
compiled = datetime.datetime.fromisoformat(metadata["HappuBuildTime"].replace("Z", "+00:00"))
if compiled.utcoffset() is None:
    raise ValueError("HappuBuildTime 必须包含时区")
compiled = compiled.astimezone(datetime.timezone(datetime.timedelta(hours=8)))
features = pathlib.Path("docs/APP_FEATURES.md").read_text(encoding="utf-8").strip()
head = git("rev-parse", f"{args.ref}^{{commit}}")
with args.releases.open(encoding="utf-8") as source:
    pages = json.load(source)
assert isinstance(pages, list), pages
published = set()
for page in pages:
    assert isinstance(page, list), page
    for release in page:
        assert isinstance(release["draft"], bool) and isinstance(release["prerelease"], bool), release
        if not release["draft"] and not release["prerelease"]:
            published.add(release["tag_name"])
previous = []
for tag in git("tag", "--merged", args.ref, "--list", "v*").splitlines():
    match = re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
    if match and tag in published and git("rev-parse", f"{tag}^{{commit}}") != head:
        previous.append((tuple(map(int, match.groups())), tag))
if previous:
    subjects = git(
        "log", "--reverse", "--format=%s", f"{max(previous)[1]}..{head}", "--",
        "Happu", "Happu.xcodeproj", "ArchiveBridge", "Vendor", "Package.swift", "Package.resolved",
        "scripts", ".github/workflows/release-ipa.yml", "docs/APP_FEATURES.md",
    ).splitlines()
    updates = [re.sub(r"^(feat|fix|refactor|perf|build|ci|test|docs|chore)(\([^)]*\))?!?:\s*", "", subject) for subject in subjects]
else:
    updates = ["首次发布 Happu，提供文件管理、文件处理、下载和局域网共享功能。", "支持自动构建 IPA 并发布到 GitHub Release。"]
changes = "\n".join("- " + update for update in updates) or "- 本次构建未包含新的应用或发布流程改动。"
body = f"## App 主要功能\n\n{features}\n\n## 本次更新内容\n\n{changes}\n\n## 编译时间\n\n{compiled:%Y-%m-%d %H:%M:%S}（北京时间，UTC+8）\n"
if args.output:
    args.output.write_text(body, encoding="utf-8")
else:
    print(body, end="")
