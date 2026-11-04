"""Check RetroArch Snes9x states for code positions that a patch would break.

Usage: python tools/statecheck.py STATE [STATE ...]
Prints where the CPU was (and, when the state was saved inside the game's NMI
handler, where the interrupted main code was), and scans the stack for the
return address of the sprite builder call at $FD:6E24 (JSR $6E9B -> $6E26).
"""
import os, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import s9xstate


def regs(b):
    r = b['REG']
    pb, db = r[0], r[1]
    p, a, d, s, x, y, pc = struct.unpack('>7H', r[2:16])
    return dict(pb=pb, db=db, p=p, a=a, d=d, s=s, x=x, y=y, pc=pc)


def check(path):
    try:
        b = s9xstate.load(path)
    except Exception as e:
        return f'unreadable ({e.__class__.__name__})'
    r = regs(b)
    ram = b['RAM']
    out = [f"PC={r['pb']:02X}:{r['pc']:04X} S={r['s']:04X}"]
    s = r['s']
    if r['pb'] == 0xC0 and 0x33A8 <= r['pc'] <= 0x3434:       # inside the NMI handler
        s = struct.unpack('<H', ram[0x1004A:0x1004C])[0]        # main stack saved at $7F:004A
        f = ram[s + 1:s + 14]                                    # B, Y, X, A, D, P, PCL, PCH, PB
        out.append(f"interrupted {f[12]:02X}:{f[11]:02X}{f[10]:02X} (main S={s:04X})")
    low = ram[:0x2000]                     # every task stack lives in $0000-$1FFF
    hits = [i for i in range(len(low) - 1) if low[i] == 0x26 and low[i + 1] == 0x6E]
    out.append('bytes 26 6E (sprite-builder return) at ' + ','.join(f'{h:04X}' for h in hits) if hits
               else 'no sprite-builder return address anywhere in $0000-$1FFF')
    return '  '.join(out)


if __name__ == '__main__':
    for p in sys.argv[1:]:
        print(f'{os.path.basename(p):40s} {check(p)}')
