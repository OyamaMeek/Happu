import hashlib
import pathlib
import struct
import sys

path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
magic, cpu, subtype, filetype, count, command_bytes, flags, reserved = struct.unpack_from("<8I", data)
if magic != 0xFEEDFACF:
    raise SystemExit("Expected a little-endian 64-bit Mach-O")

print("size:", len(data))
print("sha256:", hashlib.sha256(data).hexdigest())
print("cpu:", hex(cpu), "filetype:", filetype)
print("load_commands:", count)
offset = 32
for _ in range(count):
    command, size = struct.unpack_from("<2I", data, offset)
    if size < 8 or offset + size > 32 + command_bytes:
        raise SystemExit("Invalid load command bounds")
    kind = command & 0x7FFFFFFF
    if kind in {0xC, 0x18, 0x1F, 0x23}:
        name_offset = struct.unpack_from("<I", data, offset + 8)[0]
        name = data[offset + name_offset:offset + size].split(b"\0", 1)[0].decode("utf-8", "replace")
        print(f"dylib@{offset:#x}:", name)
    elif kind in {0x21, 0x2C}:
        cryptoff, cryptsize, cryptid = struct.unpack_from("<3I", data, offset + 8)
        print(f"encryption@{offset:#x}:", cryptoff, cryptsize, cryptid)
    offset += size
