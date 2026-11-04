import sys
rom = open(sys.argv[1],'rb').read()
start = int(sys.argv[2],16); end = int(sys.argv[3],16)
def show(b):
    s=''
    for c in b:
        if c==0xff: break
        s += chr(c) if 0x20<=c<0x7f else '{%02x}'%c
    return s
prev_empty=False
for off in range(start, end, 16):
    b = rom[off:off+16]
    if all(x==0 for x in b) or all(x==0xff for x in b):
        if not prev_empty: print(hex(off), '--empty--')
        prev_empty=True; continue
    prev_empty=False
    print(hex(off), show(b))
