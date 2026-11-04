import sys
def apply_ips(rom, patch):
    rom = bytearray(rom)
    assert patch[:5] == b'PATCH', 'not an IPS'
    i = 5; recs = []
    while True:
        if patch[i:i+3] == b'EOF' and i+3 >= len(patch)-3:
            break
        off = int.from_bytes(patch[i:i+3], 'big'); i += 3
        size = int.from_bytes(patch[i:i+2], 'big'); i += 2
        if size == 0:
            rl = int.from_bytes(patch[i:i+2], 'big'); i += 2
            data = patch[i:i+1] * rl; i += 1
        else:
            data = patch[i:i+size]; i += size
        if off + len(data) > len(rom):
            rom.extend(b'\0' * (off + len(data) - len(rom)))
        rom[off:off+len(data)] = data
        recs.append((off, len(data)))
    return bytes(rom), recs
if __name__ == '__main__':
    src, ips, out = sys.argv[1:4]
    rom, recs = apply_ips(open(src,'rb').read(), open(ips,'rb').read())
    open(out,'wb').write(rom)
    print('records', len(recs), 'bytes changed', sum(r[1] for r in recs), 'size', len(rom))
