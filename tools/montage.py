"""Stitch screenshots side by side (stdlib only).
Usage: python tools/montage.py OUT.png IN1.png IN2.png ...   (2x scale with --x2)"""
import struct, sys, zlib


def load(p):
    d = open(p, 'rb').read(); i = 8; w = h = ct = 0; idat = b''
    while i < len(d):
        n = struct.unpack('>I', d[i:i + 4])[0]; t = d[i + 4:i + 8]; c = d[i + 8:i + 8 + n]; i += 12 + n
        if t == b'IHDR': w, h, _, ct = struct.unpack('>IIBB', c[:10])
        elif t == b'IDAT': idat += c
    bpp = {2: 3, 6: 4}[ct]; raw = zlib.decompress(idat); rows = []; prev = bytearray(w * bpp); k = 0
    for _ in range(h):
        f = raw[k]; k += 1; line = bytearray(raw[k:k + w * bpp]); k += w * bpp
        for x in range(len(line)):
            a = line[x - bpp] if x >= bpp else 0; b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                q = a + b - c; pa, pb, pc = abs(q - a), abs(q - b), abs(q - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line) if bpp == 3 else b''.join(bytes(line[x * 4:x * 4 + 3]) for x in range(w)))
        prev = line
    return w, h, rows


def save(p, w, h, rows):
    raw = b''.join(b'\0' + r for r in rows)
    def ch(t, c): return struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    open(p, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                        + ch(b'IDAT', zlib.compress(raw)) + ch(b'IEND', b''))


def main():
    args = sys.argv[1:]; x2 = '--x2' in args; args = [a for a in args if a != '--x2']
    out, ins = args[0], args[1:]
    imgs = [load(f) for f in ins]
    H = max(i[1] for i in imgs); rows = []
    for y in range(H):
        r = b''
        for j, (w, h, rs) in enumerate(imgs):
            r += rs[y] if y < h else bytes(w * 3)
            if j < len(imgs) - 1: r += b'\xff\x00\xff' * 3
        rows.append(r)
    W = len(rows[0]) // 3
    if x2:
        rows = [b''.join(r[x * 3:x * 3 + 3] * 2 for x in range(W)) for r in rows for _ in (0, 1)]
        W, H = W * 2, H * 2
    save(out, W, H, rows)


if __name__ == '__main__':
    main()
