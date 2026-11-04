import sys
rom = open(sys.argv[1],'rb').read()
t = rom[0x520000:0x530000]
def s53(i):
    b = rom[0x530000+i*16:0x530000+i*16+16]; o=''
    for c in b:
        if c==0xff: break
        o += chr(c) if 0x20<=c<0x7f else '{%02x}'%c
    return o
def sfb(a, n=24):
    b = rom[0x3B0000+a:0x3B0000+a+n]; o=''
    for c in b:
        if c==0xff: break
        o += chr(c) if 0x20<=c<0x7f else '{%02x}'%c
    return o
nz = [(a, t[a]) for a in range(0x10000) if t[a]]
print('nonzero entries:', len(nz))
for a,i in nz: print(f'$FB:{a:04X} -> slot {i:02X} @$53:{i*16:04X}  new="{s53(i)}"  old="{sfb(a)}"')
