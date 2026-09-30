import pathlib
import stat
import sys
import zipfile

destination = pathlib.Path(sys.argv[1])
destination.mkdir(parents=True, exist_ok=True)
if len(sys.argv) > 2:
    with zipfile.ZipFile(sys.argv[2]) as archive:
        assert set(archive.namelist()) == {"中文/", "中文/子目录/", "中文/子目录/文本.txt", "中文/空目录/", "中文/.隐藏"}
        assert archive.read("中文/子目录/文本.txt") == "真实内容\nhello ZIP\n".encode()
for name, entry in [("traversal.zip", "../escaped.txt"), ("absolute.zip", str(destination.parent / "absolute-escaped.txt"))]:
    with zipfile.ZipFile(destination / name, "w") as archive:
        archive.writestr(entry, b"unsafe")
        archive.writestr("safe.txt", b"safe")
with zipfile.ZipFile(destination / "symlink.zip", "w") as archive:
    entry = zipfile.ZipInfo("link")
    entry.create_system = 3
    entry.external_attr = (stat.S_IFLNK | 0o777) << 16
    archive.writestr(entry, "../sentinel.txt")
with zipfile.ZipFile(destination / "ordinary.zip", "w") as archive:
    archive.writestr("independent.txt", b"independent bytes")
