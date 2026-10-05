import argparse
import json
import pathlib
import re
import subprocess


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def version_tuple(tag):
    match = re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
    return tuple(map(int, match.groups())) if match else None


parser = argparse.ArgumentParser()
parser.add_argument("--latest", type=pathlib.Path)
args = parser.parse_args()
head = git("rev-parse", "HEAD")
versions = {}
for tag in git("tag", "--list", "v*").splitlines():
    version = version_tuple(tag)
    if version is not None:
        versions[version] = tag

existing = [version for version, tag in versions.items() if git("rev-parse", f"{tag}^{{commit}}") == head]
if existing:
    selected = max(existing)
else:
    major, minor, patch = max(versions, default=(0, 0, 0))
    selected = major, minor, patch + 1

if args.latest:
    with args.latest.open() as source:
        pages = json.load(source)
    assert isinstance(pages, list), pages
    published = []
    for page in pages:
        assert isinstance(page, list), page
        for release in page:
            assert isinstance(release["draft"], bool) and isinstance(release["prerelease"], bool), release
            version = version_tuple(release["tag_name"])
            if version is not None and not release["draft"] and not release["prerelease"]:
                published.append(version)
    print("true" if selected >= max(published, default=(0, 0, 0)) else "false")
else:
    print("v" + ".".join(map(str, selected)))
