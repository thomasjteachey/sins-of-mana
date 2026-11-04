"""Tiny PNG writer (no PIL): write_png(path, width, height, rows_of_rgb_tuples, scale)."""
import struct, zlib


def write_png(path, w, h, pix, scale=1):
    raw = bytearray()
    for y in range(h * scale):
        raw.append(0)
        row = pix[y // scale]
        for x in range(w * scale):
            raw += bytes(row[x // scale])
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w * scale, h * scale, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)


def snes_rgb(c):
    return ((c & 31) * 255 // 31, ((c >> 5) & 31) * 255 // 31, ((c >> 10) & 31) * 255 // 31)


def tile4(v, off):
    """4bpp tile at byte offset -> 8x8 list of colour indices."""
    t = []
    for y in range(8):
        p0, p1, p2, p3 = v[off + y * 2], v[off + y * 2 + 1], v[off + 16 + y * 2], v[off + 16 + y * 2 + 1]
        t.append([((p0 >> (7 - x)) & 1) | (((p1 >> (7 - x)) & 1) << 1) | (((p2 >> (7 - x)) & 1) << 2) | (((p3 >> (7 - x)) & 1) << 3) for x in range(8)])
    return t


def read_png(path):
    """Read an 8-bit RGB/RGBA PNG -> (w, h, rows of (r,g,b))."""
    d = open(path, 'rb').read()
    i, idat, w = 8, b'', None
    while i < len(d):
        n = struct.unpack('>I', d[i:i + 4])[0]
        t = d[i + 4:i + 8]
        body = d[i + 8:i + 8 + n]
        if t == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
            bpp = {2: 3, 6: 4}[ctype]
        elif t == b'IDAT':
            idat += body
        i += 12 + n
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev, p = [], bytearray(stride), 0
    for y in range(h):
        f = raw[p]; line = bytearray(raw[p + 1:p + 1 + stride]); p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append([tuple(line[x * bpp:x * bpp + 3]) for x in range(w)])
        prev = line
    return w, h, rows


def crop_zoom(src, dst, x0, y0, x1, y1, scale):
    w, h, rows = read_png(src)
    sx = w // 256 if w >= 512 else 1          # Mesen hi-res shots are 512 wide
    sub = [r[x0 * sx:x1 * sx:sx] for r in rows[y0 * sx:y1 * sx:sx]]
    write_png(dst, x1 - x0, y1 - y0, sub, scale)
