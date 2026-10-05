import argparse
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import zipfile


parser = argparse.ArgumentParser()
parser.add_argument("app", type=pathlib.Path)
parser.add_argument("output", type=pathlib.Path)
parser.add_argument("version")
parser.add_argument("build")
args = parser.parse_args()
app = args.app.resolve()
output = args.output.resolve()
if output.exists():
    raise FileExistsError(output)
with (app / "Info.plist").open("rb") as source:
    metadata = plistlib.load(source)
assert app.name == "Happu.app", app
assert metadata["CFBundleShortVersionString"] == args.version, metadata
assert metadata["CFBundleVersion"] == args.build, metadata
assert metadata["CFBundleIdentifier"] == "com.happu.shureplica", metadata
assert metadata["CFBundleExecutable"] == "Happu", metadata
assert metadata["DTPlatformName"] == "iphoneos", metadata
assert metadata["HappuBuildTime"], metadata
binary = app / metadata["CFBundleExecutable"]
architectures = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).split()
assert "arm64" in architectures, architectures
assert binary.stat().st_size > 0, binary
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(dir=output.parent) as directory:
    payload = pathlib.Path(directory) / "Payload"
    shutil.copytree(app, payload / app.name, symlinks=True)
    archive = pathlib.Path(directory) / output.name
    subprocess.run(["ditto", "-c", "-k", "--keepParent", str(payload), str(archive)], check=True)
    with zipfile.ZipFile(archive) as ipa:
        assert ipa.testzip() is None, "IPA ZIP 校验失败"
        assert plistlib.loads(ipa.read("Payload/Happu.app/Info.plist")) == metadata
        assert ipa.getinfo("Payload/Happu.app/Happu").file_size == binary.stat().st_size
    archive.rename(output)
print(f"IPA 验证通过：{output}，版本 {args.version}，构建 {args.build}")
