"""Read a RetroArch Snes9x save state (.stateN, RZIP or raw).
Usage (module): blocks = load(path) -> dict name -> bytes  (RAM, VRA, SRA, CPU, PPU, ...)"""
import struct, sys, zlib


def unrzip(d):
    if d[:8] != b'#RZIPv\x01#':
        return d
    i = 20
    out = bytearray()
    while i < len(d):
        n = struct.unpack('<I', d[i:i + 4])[0]
        i += 4
        out += zlib.decompress(d[i:i + n])
        i += n
    return bytes(out)


def load(path):
    d = unrzip(open(path, 'rb').read())
    if d[:8] == b'RASTATE\x01':          # RetroArch container: chunks of 4-char id + 4-byte size
        i = 8
        while i < len(d):
            cid, size = d[i:i + 4], struct.unpack('<I', d[i + 4:i + 8])[0]
            if cid == b'MEM ':
                d = d[i + 8:i + 8 + size]
                break
            i += 8 + size
    assert d.startswith(b'#!s9xsnp:'), d[:16]
    i = d.index(b'\n') + 1
    blocks = {}
    while i < len(d):
        name = d[i:i + 3].decode('latin1')
        size = int(d[i + 4:i + 10])
        blocks[name] = d[i + 11:i + 11 + size]
        i += 11 + size
    return blocks


if __name__ == '__main__':
    b = load(sys.argv[1])
    for k, v in b.items():
        print(k, len(v))
