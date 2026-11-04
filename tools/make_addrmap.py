"""Write ADDRESSES.md: every ROM range each patch in build/ writes, what it is, and the
RAM / VRAM / DMA the patches use.

Usage: python tools/make_addrmap.py   (after tools/build.py; build.py also runs it)

The ranges come from the built .ips files. Each one must fall inside an entry of RANGES
below (the script stops otherwise, so a new hook can't go undocumented). "Blank in
2.060" is checked against build/som_base.sfc.
"""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build import ips_bytes, ALL_PATCHES, BAR_FEATURES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'build')
DOC = os.path.join(ROOT, 'ADDRESSES.md')

ENGINE = [ips for _, ips in BAR_FEATURES]          # same engine, own switch each
DESC, NOPOP, FAST = ('sinofmana_equip_descriptions.ips', 'no_popup_messages_fixed.ips',
                     'sinofmana_fast_menus.ips')
SWITCH_OF = {ips: name for name, ips in BAR_FEATURES}

# (first, last, patches, kind, what). kind: hook = overwrites game/mod code, data = edits
# existing data, free = space the patch owns (the whole reserved block is listed).
RANGES = [
    # bar / panel engine, in all eight feature patches
    (0xC022BC, 0xC022C2, ENGINE, 'hook', 'NMI, where the game re-enables HDMA after its uploads (`LDA $0032 : STA $420C`) -> `JSL NmiHdma`: points HDMA channel 1 at the bar table'),
    (0xC45EF5, 0xC45EF9, ENGINE, 'hook', 'end of the HUD flicker step (`LDA $7F0330 : ORA #4 : STA $7F0330 : RTS`) -> `JSL PulseFix`'),
    (0xC46A79, 0xC46A7D, ENGINE, 'hook', 'text op that prints a monster\'s name (target bar), `LDA $7F0090,X : ASL` -> `JSL WeakName`'),
    (0xD0FB12, 0xD0FB15, ENGINE, 'hook', 'cast start, `JSL $C40018` -> `JSL CastStart` (notes the cast length)'),
    (0xFD6E24, 0xFD6E28, ENGINE, 'hook', 'sprite builder in the main loop, `JSR $6E9B : SEP #$20` -> `JSL Bars` (runs the engine once per frame)'),
    (0xCBE400, 0xCBF4EF, ENGINE, 'free', 'engine code: bars, HUD buff icons, NMI part (FastROM)'),
    (0xCBF4F0, 0xCBF4FF, ENGINE, 'free', 'feature switches, one word each: `$FFFF` off, `$0000` on (table below)'),
    (0x56A000, 0x56FFFF, ENGINE, 'free', 'engine code: `CastStart`, `PulseFix`, cast timing'),
    (0x580000, 0x58FFFF, ENGINE, 'free', 'info panels (level-up, shop, enemy weaknesses): code and texts'),
    # equipment descriptions
    (0x407960, 0x407963, [DESC], 'hook', 'the mod\'s text redirect hook (from `$C0:EAF4`) -> `JML NewRedirect`'),
    (0xC481AB, 0xC481AF, [DESC], 'hook', 'EQUIP slot cursor moved -> `JSL SlotHelpRedraw` (redraw the help box)'),
    (0xC481F5, 0xC481F9, [DESC], 'hook', 'same, second spot'),
    (0xC4828B, 0xC4828F, [DESC], 'hook', 'same, third spot'),
    (0xE8C19E, 0xE8C1A8, [DESC], 'hook', 'icon palette copy -> `JSL IconSlot` (keeps the palette index 0-11; a bad one corrupted room tiles after the equip screen)'),
    (0x530F80, 0x530FEF, [DESC], 'data', 'the mod\'s string slots `$F8`-`$FE`: the EQUIP screen\'s default help text'),
    (0x538000, 0x53FFFF, [DESC], 'free', '`DescTable` + description texts (must be in bank `$53`: the mod\'s glyph reader `$40:7920` only reads plain ASCII there)'),
    (0x568000, 0x569FFF, [DESC], 'free', 'code: `NewRedirect`, `GetHelpDesc`, `SlotHelpRedraw`, `IconSlot`'),
    # no popup messages (fixed)
    (0xD0CDFD, 0xD0CDFD, [NOPOP], 'hook', '`RTS`: the stat change popup loop'),
    (0xD0CE53, 0xD0CE53, [NOPOP], 'hook', 'original first instruction `STX $1A` put back (the old patch\'s `RTS` here stopped stat buffs working)'),
    (0xD0CEEA, 0xD0CEF7, [NOPOP], 'hook', '`NOP`s over the "wore off" message calls'),
    (0xD0CF6B, 0xD0CFA2, [NOPOP], 'hook', '`NOP`s over the "gained" / "lost" message calls'),
    (0xD0D01A, 0xD0D01A, [NOPOP], 'hook', '`RTS`: status ailment messages (as in the original patch)'),
    # fast menus
    (0xC0ED4D, 0xC0ED52, [FAST], 'hook', 'menu text: copy a character into the shift buffer -> `JSL TextLoad`'),
    (0xC0F07A, 0xC0F07E, [FAST], 'hook', 'menu text: draw its shadowed rows -> `JSL TextRows`'),
    (0xC1D9DF, 0xC1D9E4, [FAST], 'hook', '32x32 icon uploads -> `JSL IconJobs4`'),
    (0xC1DA8D, 0xC1DA93, [FAST], 'hook', 'the other icon size -> `JSL IconJobs2`'),
    (0xC23B87, 0xC23B8B, [FAST], 'hook', 'field graphics decoder -> `JSL FastField`'),
    (0xC44DA6, 0xC44DAF, [FAST], 'hook', 'heap request for menu text line uploads (`LDA #$0958`)'),
    (0xC48CB7, 0xC48CB8, [FAST], 'data', 'pause on black before the menu loads: 2 frames (was 16)'),
    (0xC491F6, 0xC491FA, [FAST], 'hook', 'fade-in -> `JSL FadeIn` (8 steps)'),
    (0xC4923F, 0xC49251, [FAST], 'hook', 'fade-out loop: brightness -2 per frame'),
    (0xC49840, 0xC49844, [FAST], 'hook', 'menu text line upload -> `JSL TextUpload`'),
    (0xE8C480, 0xE8C487, [FAST], 'hook', 'graphics decoders -> `JML FastStretch` / `JML FastTiles`'),
    (0xE8CD19, 0xE8CD98, [FAST], 'data', 'submenu page slide: 16 steps (was 32)'),
    (0xCBF500, 0xCBFCFF, [FAST], 'free', 'code: fades, decoders, text engine (FastROM)'),
    (0x570000, 0x57FFFF, [FAST], 'free', 'pixel-doubling tables for the faster decoder'),
]

RAM = [
    ('`$7E:2800-$7E:28FF`', 'bar / panel engine work RAM (`!Ram` in `src/bars.asm`); `$7E:28F0-28F3` is shared with the equipment descriptions (last item name printed, for the shop panel)'),
    ('`$7E:2BD0`', 'fast menus: text lines queued since the last pause (`TextCount`)'),
]
GAME_RAM = [
    ('`$7E:4000-$7E:47FF`', 'the game\'s BG3 tilemap copy: the engine writes the HUD icon cells beside the status blocks, the info panels (rows 4-6 / 8-10) and the bars\' off-screen rows 28-31'),
    ('`$7E:2040`', 'entity table (read)'),
    ('`$7F:xxxx`', 'entity records, timer records (`$7F:00C4` list, `$7F:00C6` clock), `$2105` copy `$7F:0805`, HDMA enables `$7F:0032` (read)'),
    ('`$7F:F255`, `$7F:F260`', 'ring menu script: target slot and script stack (read, enemy weaknesses)'),
]
OTHER = [
    ('BG3 tiles `$0C0-$0E8`', 'bar tiles (`$0C0-$0D3`), HUD buff icons (`$0D4-$0DC`) and the panels\' punctuation (`$0DD-$0E8`); sent to VRAM every 64 frames and after menus'),
    ('BG3 rows 28-31', 'off-screen tilemap rows the bars are drawn in'),
    ('HDMA channel 1', 'BG3 scroll on the bar lines (field only; off in menus)'),
    ('CGRAM 21-23', 'BG3 palette 5: borrowed for the red buff marks while they show'),
    ('DMA', 'all uploads go through the game\'s own queue (`$C0:0560` / `$C0:0568`, channel 0)'),
]


def snes(a):
    return '$%02X:%04X' % (a >> 16, a & 0xFFFF)


def file_off(a):
    bank = a >> 16
    return ((bank - 0xC0) << 16 | (a & 0xFFFF)) if bank >= 0xC0 else 0x400000 + ((bank - 0x40) << 16) + (a & 0xFFFF)


def to_snes(o):
    return (0xC00000 + o) if o < 0x400000 else (0x400000 + o - 0x400000)


def main():
    base = open(os.path.join(OUT, 'som_base.sfc'), 'rb').read()
    used = {}                                           # entry index -> addresses written (all its patches)
    sizes = {}
    for p in ALL_PATCHES:
        b = ips_bytes(os.path.join(OUT, p))
        sizes[p] = len(b)
        for o in b:
            a = to_snes(o)
            hit = [i for i, r in enumerate(RANGES) if r[0] <= a <= r[1] and p in r[2]]
            if not hit:
                sys.exit('%s writes %s, which ADDRESSES.md does not describe: add it to RANGES' % (p, snes(a)))
            used.setdefault(hit[0], set()).add(a)

    out = ['# Address map', '',
           'Every ROM range the add-on patches write, on top of Sin of Mana 2.060 (ExHiROM;',
           '`$C0-$FF` = file `0x000000-0x3FFFFF`, `$40-$7D` = file `0x400000+`). Generated by',
           '`tools/make_addrmap.py` from the built `.ips` files, so it matches them byte for byte.', '',
           '- **hook**: overwrites a few bytes of existing code (usually a `JSL` into new code).',
           '- **data**: changes existing data.',
           '- **free**: new code / data in space that is blank in 2.060. The whole block the patch reserves is listed;',
           '  "written" is the part the current build fills.',
           '- "Written" counts only bytes that differ from 2.060 (an IPS skips the rest).', '',
           'The eight bar / panel patches (%s) carry the same engine, so they write the same bytes except their own'
           % ', '.join('`%s`' % p for p in ENGINE),
           '2-byte switch. Any mix of the patches applies cleanly: `tools/build.py` checks that no two of them disagree on a byte.', '']

    groups = [('Bar / panel engine (all eight feature patches)', ENGINE), ('`%s`' % DESC, [DESC]),
              ('`%s`' % NOPOP, [NOPOP]), ('`%s`' % FAST, [FAST])]
    for title, patches in groups:
        out += ['## ' + title, '', '| Range | Kind | Written | Blank in 2.060 | What |', '|---|---|---|---|---|']
        for i, (lo, hi, ps, kind, what) in enumerate(RANGES):
            if ps != patches or i not in used:
                continue
            w = used[i]
            e = (min(w), max(w), len(w))
            rng = snes(lo) if lo == hi else '%s-%s' % (snes(lo), snes(hi)[4:] if lo >> 16 == hi >> 16 else snes(hi))
            wrote = snes(e[0]) if e[0] == e[1] else '%s-%s' % (snes(e[0]), snes(e[1])[4:])
            blank = '-'
            if kind == 'free':
                chunk = base[file_off(lo):file_off(hi) + 1]
                blank = 'yes ($%02X)' % chunk[0] if len(set(chunk)) == 1 else 'NO'
            out.append('| `%s` | %s | `%s` (%d byte%s) | %s | %s |' % (rng, kind, wrote, e[2], '' if e[2] == 1 else 's', blank, what))
        out.append('')
        if patches == ENGINE:
            out += ['Feature switches:', '', '| Address | Patch |', '|---|---|']
            from build import feature_switches
            sw = feature_switches(os.path.join(ROOT, 'src', 'bars.asm'))
            for name, ips in BAR_FEATURES:
                out.append('| `%s` | `%s` (`%s`) |' % (snes(sw[name]), ips, name))
            out.append('')

    out += ['## Patch sizes', '', '| Patch | Bytes written |', '|---|---|']
    out += ['| `%s` | %d |' % (p, sizes[p]) for p in ALL_PATCHES]
    out += ['', '## RAM', '', 'Used by the patches:', '', '| Address | Use |', '|---|---|']
    out += ['| %s | %s |' % r for r in RAM]
    out += ['', 'Game RAM they read or write:', '', '| Address | Use |', '|---|---|']
    out += ['| %s | %s |' % r for r in GAME_RAM]
    out += ['', '## Other hardware resources (bar / panel engine)', '', '| Resource | Use |', '|---|---|']
    out += ['| %s | %s |' % r for r in OTHER]
    out += ['', 'More detail on each feature (how it was found, what the hooked code does): `NOTES.md`.', '']
    open(DOC, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
    print('wrote ADDRESSES.md')


if __name__ == '__main__':
    main()
