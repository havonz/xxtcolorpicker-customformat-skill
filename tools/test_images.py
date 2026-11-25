"""Pixel checks for the two image functions, using the same Lua input in either runtime."""
import json
import struct
import subprocess
import zlib


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def mask(hex_png):
    png = bytes.fromhex(hex_png)
    assert png.startswith(b"\x89PNG\r\n\x1a\n")
    pos = 8
    data = bytearray()
    palette = None
    while pos < len(png):
        size, kind = struct.unpack_from(">I4s", png, pos)
        segment = png[pos + 8:pos + 8 + size]
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", segment)
            assert (width, height, interlace) == (8, 1, 0) and depth in (1, 8) and color in (0, 3)
        elif kind == b"PLTE":
            palette = [tuple(segment[i:i + 3]) for i in range(0, size, 3)]
        elif kind == b"IDAT":
            data.extend(segment)
        pos += size + 12

    scanline = zlib.decompress(data)
    row = bytearray(scanline[1:])
    # For a single scanline the preceding row is zero; Paeth consequently selects the left byte.
    filters = (lambda left: 0, lambda left: left, lambda left: 0, lambda left: left // 2, lambda left: left)
    for i in range(1, len(row)):
        row[i] = (row[i] + filters[scanline[0]](row[i - 1])) & 255
    samples = row if depth == 8 else [(row[0] >> (7 - i)) & 1 for i in range(8)]
    white = []
    for s in samples:
        if color == 3:
            assert palette[s] in ((0, 0, 0), (255, 255, 255)), palette[s]
            white.append(palette[s][0] == 255)
        else:
            assert s in (0, (1 << depth) - 1), s
            white.append(s != 0)
    return "".join("1" if lit else "0" for lit in white)


def verify_images(work, cli, host):
    pixels = bytes.fromhex("000000 7f7f7f 808080 ffffff ff0000 00ff00 0000ff ff8000")
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 8, 1, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(b"\0" + pixels)) + chunk(b"IEND", b""))
    rules = [
        ("thresholdImageData(data, 127)", "00110101"),
        ("thresholdImageData(data, -1)", "01110101"),
        ("binaryzationImageData(data, {{0x808080,0x010101},{0xFF0000,0x008000}})", "01101001"),
        ("binaryzationImageData(data, {white_background=true,{0x808080,0x010101},{0xFF0000,0x008000}})", "10010110"),
        ("binaryzationImageData(data, {csim_mode=true,{0xFF0000,65}})", "00001000"),
        ("binaryzationImageData(data, {csim_mode=true,csim_algorithm=1,{0xFF0000,80}})", "00001001"),
        ("binaryzationImageData(data, {csim_mode=true,csim_algorithm=2,{0xFF0000,80}})", "00001000"),
        ("binaryzationImageData(data, {csim_mode=true,csim_algorithm=2,{0xFF0000,65}})", "00001001"),
        ("binaryzationImageData(data, {})", "00000000"),
    ]
    script = work / "image-mask.lua"
    body = "\n".join(f"function() return hex({expr}) end," for expr, _ in rules)
    data = "".join(f"\\{c:03d}" for c in png)
    script.write_text('local data="' + data + '"\n'
                      'local function hex(s) return (s:gsub(".", function(c) return string.format("%02x",c:byte()) end)) end\n'
                      'return {name="像素检查",formats={settingsRule={title="设置",args={}},'
                      'multiPosFormatRule=function() return "" end,makeScriptRules={' + body + '}}}', encoding="utf-8")
    fixture = work / "image-case.json"
    fixture.write_text('{"points":[]}', encoding="utf-8")
    for flags in ([[], ["--host", host]] if host else [[]]):
        proc = subprocess.run(cli + ["check", str(script), "--case", str(fixture)] + flags,
                              text=True, capture_output=True, timeout=70)
        assert proc.returncode == 0, proc.stdout + proc.stderr
        rows = json.loads(proc.stdout.split("\n", 1)[1])["rows"]
        assert len(rows) == len(rules)
        for (expr, expected), row in zip(rules, rows):
            actual = mask(row[0])
            assert actual == expected, (flags, expr, expected, actual)
