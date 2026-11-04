"""Build the equipment-description add-on.

Steps:
  1. clean Japanese ROM + Sin of Mana 2.060 patch -> build/som_base.sfc
  2. Asar applies src/main.asm on a copy           -> build/som_desc.sfc
  3. diff of the two                               -> build/sinofmana_equip_descriptions.ips

Usage:  python tools/build.py [--difficulty N]   (N = 1..5, applied to a test copy only)
"""
import hashlib, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from ips import apply_ips

CLEAN_ROM = os.path.join(ROOT, 'Seiken Densetsu 3 (Japan).sfc')
CLEAN_MD5 = '58ebd7cbf28ceadc03aec4f448956a0b'
MOD_IPS = os.path.join(ROOT, 'Seiken Densetsu 3 (J)_sinofmana_2060.ips')
ASAR = os.path.join(ROOT, 'third_party', 'asar', 'asar.exe')
MAIN_ASM = os.path.join(ROOT, 'src', 'main.asm')
OUT = os.path.join(ROOT, 'build')


# Bars engine features: switch label in src/bars.asm -> patch file.
BAR_FEATURES = [
    ('FeatRevenge', 'sinofmana_revenge_bar.ips'),
    ('FeatMarkers', 'sinofmana_enemy_buff_markers.ips'),
    ('FeatCastParty', 'sinofmana_party_cast_bar.ips'),
    ('FeatCastEnemy', 'sinofmana_enemy_cast_bar.ips'),
    ('FeatHudIcons', 'sinofmana_party_buff_icons.ips'),
    ('FeatLevelInfo', 'sinofmana_levelup_info.ips'),
    ('FeatShopInfo', 'sinofmana_shop_descriptions.ips'),
]
ALL_PATCHES = (['sinofmana_equip_descriptions.ips', 'no_popup_messages_fixed.ips', 'sinofmana_fast_menus.ips']
               + [ips for _, ips in BAR_FEATURES])


def asm(source, rom_path):
    r = subprocess.run([ASAR, '--fix-checksum=off', '--no-title-check', source, rom_path],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f'asar failed on {os.path.basename(source)}:\n' + r.stdout + r.stderr)


def snes_to_file(addr):
    """ExHiROM: $C0-$FF:xxxx -> 0x000000-0x3FFFFF, $40-$7D:xxxx -> 0x400000+."""
    bank = addr >> 16
    if bank >= 0xC0:
        return ((bank - 0xC0) << 16) | (addr & 0xFFFF)
    return 0x400000 + (((bank - 0x40) << 16) | (addr & 0xFFFF))


def feature_switches(path):
    """'FeatName = $CBF4F0' lines of an asm file -> {name: address}."""
    import re
    found = {}
    for line in open(path, encoding='utf-8'):
        m = re.match(r'\s*(Feat\w+)\s*=\s*\$([0-9A-Fa-f]{6})', line)
        if m:
            found[m.group(1)] = int(m.group(2), 16)
    return found


def ips_bytes(path):
    """IPS file -> {offset: byte} (plain and RLE records)."""
    d = open(path, 'rb').read()
    assert d[:5] == b'PATCH', path
    out, i = {}, 5
    while d[i:i + 3] != b'EOF':
        off = int.from_bytes(d[i:i + 3], 'big')
        size = int.from_bytes(d[i + 3:i + 5], 'big')
        i += 5
        if size:
            for k in range(size):
                out[off + k] = d[i + k]
            i += size
        else:
            run = int.from_bytes(d[i:i + 2], 'big')
            for k in range(run):
                out[off + k] = d[i + 2]
            i += 3
    return out


def check_patches(paths):
    data = {os.path.basename(p): ips_bytes(p) for p in paths}
    names = sorted(data)
    for a in range(len(names)):
        for b in range(a + 1, len(names)):
            pa, pb = data[names[a]], data[names[b]]
            bad = [o for o in pa.keys() & pb.keys() if pa[o] != pb[o]]
            if bad:
                sys.exit(f'{names[a]} and {names[b]} disagree at {len(bad)} bytes, e.g. 0x{min(bad):06X}')
    print(f'checked {len(names)} patches: no conflicting bytes')


def make_ips(old, new, force=()):
    """Smallest-effort IPS writer: one record per changed run (max 0xFFFF bytes each).
    force: (offset, length) ranges written even if they match `old`."""
    out = bytearray(b'PATCH')
    for start, length in force:
        out += start.to_bytes(3, 'big') + length.to_bytes(2, 'big') + new[start:start + length]
    i, n = 0, len(new)
    while i < n:
        if i < len(old) and old[i] == new[i]:
            i += 1
            continue
        start = i
        while i < n and (i >= len(old) or old[i] != new[i]) and i - start < 0xFFFF:
            i += 1
        if start == 0x454F46:  # this offset reads as "EOF"; start one byte earlier
            start -= 1
        out += start.to_bytes(3, 'big') + (i - start).to_bytes(2, 'big') + new[start:i]
    out += b'EOF'
    return bytes(out)


DESC_TXT = os.path.join(ROOT, 'src', 'descriptions.txt')
DESC_ASM = os.path.join(OUT, 'desc.asm')

# Name slots (in the mod's $53 name bank) that belong to each gear type.
CATEGORY_SLOTS = {
    'weapons': list(range(0x11, 0x30)) + list(range(0xB1, 0xC0)) + list(range(0xD1, 0xF0)),
    'helms': list(range(0x31, 0x40)),
    'armor': list(range(0x41, 0x60)),
    'accessories': list(range(0x61, 0xA0)),
    'shields': list(range(0xA1, 0xB0)),
}
# Characters the menu font can show (checked against the name-entry screen).
SAFE_CHARS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,!?&:+-*/=()'%[]~")
MAX_LINE = 40


def slot_names(rom):
    names = {}
    for slot in range(256):
        raw = rom[0x530000 + slot * 16: 0x530000 + slot * 16 + 16].split(b'\xff')[0]
        names[slot] = bytes(c for c in raw if 0x20 <= c < 0x7f).decode('ascii').strip()
    return names


def parse_descriptions(path):
    """-> list of (category, name, [lines], line_no)"""
    entries, cat, cur = [], None, None
    for n, raw in enumerate(open(path, encoding='utf-8'), 1):
        line = raw.rstrip('\n').rstrip()
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if line.startswith('=='):
            cat = line.strip('= ').lower()
            if cat not in CATEGORY_SLOTS:
                sys.exit(f'descriptions.txt:{n}: unknown section "{cat}"')
            cur = None
        elif line.startswith('[') and line.endswith(']'):
            if cat is None:
                sys.exit(f'descriptions.txt:{n}: item before any == Section ==')
            cur = (cat, line[1:-1], [], n)
            entries.append(cur)
        else:
            if cur is None:
                sys.exit(f'descriptions.txt:{n}: text outside an [Item] block')
            cur[2].append(line.strip())
    return entries


def make_desc_asm(base):
    names = slot_names(base)
    table = {}
    warnings = 0
    for cat, name, lines, n in parse_descriptions(DESC_TXT):
        slots = [s for s in CATEGORY_SLOTS[cat] if names[s] == name]
        if not slots:
            sys.exit(f'descriptions.txt:{n}: no {cat} item is named "{name}" in the ROM')
        if len(lines) > 2:
            print(f'warning: descriptions.txt:{n} [{name}] has {len(lines)} lines; only 2 fit')
            warnings += 1
        for i, ln in enumerate(lines[:2]):
            bad = sorted(set(ln) - SAFE_CHARS)
            if bad:
                sys.exit(f'descriptions.txt:{n} [{name}]: characters the font may not have: {bad}')
            if len(ln) > LINE_LENGTHS[i]:
                sys.exit(f'descriptions.txt:{n} [{name}] line {i + 1} is {len(ln)} characters, '
                         f'max {LINE_LENGTHS[i]}: "{ln}"')
        lines = lines[:2]
        for s in slots:
            table[s] = lines
    out = ['; Generated by tools/build.py from src/descriptions.txt. Do not edit.', 'DescTable:']
    for s in range(256):
        out.append(f'\tdw {"Desc_%02X" % s if s in table else "$0000"}\t; slot ${s:02X} {names[s]}')
    for s, lines in sorted(table.items()):
        data = help_text_bytes(lines)
        out.append(f'Desc_{s:02X}:\t; {names[s]}')
        for k in range(0, len(data), 16):
            out.append('\tdb ' + ','.join(f'${b:02X}' for b in data[k:k + 16]))
    # The game's own help text, padded the same way so it takes the same tiles.
    default = help_text_bytes(['Select the new equipment', 'and press the Confirm button.'])
    assert len(default) <= 0x70, 'default help text no longer fits its slot'
    out.append('DefaultHelp = $530F80')
    out.append('pushpc')
    out.append('org DefaultHelp')
    for k in range(0, len(default), 16):
        out.append('\tdb ' + ','.join(f'${b:02X}' for b in default[k:k + 16]))
    out.append('pullpc')
    open(DESC_ASM, 'w').write('\n'.join(out) + '\n')
    print(f'descriptions: {len(table)} name slots filled, {warnings} warnings')


# Text tile budget. The menu font packs 2 characters per 16-pixel cell, and the
# equip screen's tile pool is full: the help box owns exactly 31 cells (the size
# of the main-menu preview text that is drawn there first). Every help text is
# padded with spaces to exactly these line lengths, so each redraw uses the same
# 31 cells: never more (that would overwrite the item list's tiles) and never a
# different split (that would leave old text behind).
LINE_LENGTHS = (32, 30)


def help_text_bytes(lines):
    data = [0xC1]                       # normal text colour
    for i, width in enumerate(LINE_LENGTHS):
        ln = lines[i] if i < len(lines) else ''
        if len(ln) > width:
            raise ValueError(f'line {i + 1} is {len(ln)} characters (max {width}): "{ln}"')
        if i:
            data.append(0x12)           # new line
        data += list(ln.ljust(width).encode('ascii'))
    data.append(0xFF)
    return data


def main():
    os.makedirs(OUT, exist_ok=True)
    clean = open(CLEAN_ROM, 'rb').read()
    md5 = hashlib.md5(clean).hexdigest()
    if md5 != CLEAN_MD5:
        sys.exit(f'clean ROM MD5 is {md5}, expected {CLEAN_MD5} (needs the unheadered Japanese ROM)')

    base, _ = apply_ips(clean, open(MOD_IPS, 'rb').read())
    base_path = os.path.join(OUT, 'som_base.sfc')
    open(base_path, 'wb').write(base)
    make_desc_asm(base)

    desc_path = os.path.join(OUT, 'som_desc.sfc')
    shutil.copyfile(base_path, desc_path)
    r = subprocess.run([ASAR, '--fix-checksum=off', '--no-title-check', MAIN_ASM, desc_path],
                       capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    if r.returncode != 0:
        sys.exit('asar failed')

    desc = open(desc_path, 'rb').read()
    patch = make_ips(base, desc)
    ips_path = os.path.join(OUT, 'sinofmana_equip_descriptions.ips')
    open(ips_path, 'wb').write(patch)
    changed = sum(1 for a, b in zip(base, desc) if a != b) + max(0, len(desc) - len(base))
    print(f'built {os.path.relpath(desc_path, ROOT)}  ({changed} bytes differ from Sin of Mana)')
    print(f'patch {os.path.relpath(ips_path, ROOT)}  ({len(patch)} bytes)')

    # Fixed "no popup messages" patch (separate, optional).
    nopop_path = os.path.join(OUT, 'som_nopopup.sfc')
    shutil.copyfile(base_path, nopop_path)
    r = subprocess.run([ASAR, '--fix-checksum=off', '--no-title-check',
                        os.path.join(ROOT, 'src', 'no_popup_fixed.asm'), nopop_path],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit('asar failed on no_popup_fixed.asm:\n' + r.stdout + r.stderr)
    nopop_ips = os.path.join(OUT, 'no_popup_messages_fixed.ips')
    # Always write $D0:CE53 (file 0x10CE53) so the patch also repairs ROMs that
    # already have the old, broken no_popup_messages patch.
    open(nopop_ips, 'wb').write(make_ips(base, open(nopop_path, 'rb').read(), force=[(0x10CE53, 1)]))
    print(f'patch {os.path.relpath(nopop_ips, ROOT)}')

    # Bars engine (src/bars.asm): one patch per feature. Each holds the whole engine (the
    # same bytes in all of them) plus its own feature switch, so any mix applies cleanly.
    import make_bargfx, make_levelinfo
    make_bargfx.write(os.path.join(OUT, 'bargfx.asm'))     # bar tiles, included by bars.asm
    make_levelinfo.write(os.path.join(OUT, 'levelinfo.asm'))   # level-up panel texts, too
    core_path = os.path.join(OUT, 'som_bars_core.sfc')
    shutil.copyfile(base_path, core_path)
    asm(os.path.join(ROOT, 'src', 'bars.asm'), core_path)
    core = open(core_path, 'rb').read()
    switches = feature_switches(os.path.join(ROOT, 'src', 'bars.asm'))
    for name, ips_name in BAR_FEATURES:
        off = snes_to_file(switches[name])
        assert core[off:off + 2] == b'\xff\xff', f'{name} switch is not blank ROM'
        rom = bytearray(core)
        rom[off:off + 2] = b'\x00\x00'
        open(os.path.join(OUT, ips_name), 'wb').write(make_ips(base, rom))
        print(f'patch build/{ips_name}')
    stale = os.path.join(OUT, 'sinofmana_bars.ips')         # replaced by the feature patches
    if os.path.exists(stale):
        os.remove(stale)

    # Faster menus (src/menuspeed.asm), against the base game too.
    fast_path = os.path.join(OUT, 'som_fast.sfc')
    shutil.copyfile(base_path, fast_path)
    asm(os.path.join(ROOT, 'src', 'menuspeed.asm'), fast_path)
    fast_ips = os.path.join(OUT, 'sinofmana_fast_menus.ips')
    open(fast_ips, 'wb').write(make_ips(base, open(fast_path, 'rb').read()))
    print(f'patch {os.path.relpath(fast_ips, ROOT)}')

    # Test ROM with everything: descriptions + every bar feature + faster menus.
    test_path = os.path.join(OUT, 'som_test.sfc')
    shutil.copyfile(desc_path, test_path)
    asm(os.path.join(ROOT, 'src', 'bars.asm'), test_path)
    test = bytearray(open(test_path, 'rb').read())
    for name, _ in BAR_FEATURES:
        off = snes_to_file(switches[name])
        test[off:off + 2] = b'\x00\x00'
    open(test_path, 'wb').write(test)
    asm(os.path.join(ROOT, 'src', 'menuspeed.asm'), test_path)
    print('test ROM with everything: build/som_test.sfc')

    # No two patches may write different bytes to the same place.
    check_patches([os.path.join(OUT, n) for n in ALL_PATCHES])

    if '--difficulty' in sys.argv:
        n = int(sys.argv[sys.argv.index('--difficulty') + 1])
        names = {1: 'wuss', 2: 'easy', 3: 'normal', 4: 'tough', 5: 'hard'}
        dpatch = os.path.join(ROOT, 'difficulty_changer',
                              f'Seiken Densetsu 3 (J)_sinofmana_change_difficulty_0{n}_{names[n]}.ips')
        test, _ = apply_ips(desc, open(dpatch, 'rb').read())
        open(os.path.join(OUT, f'som_desc_{names[n]}.sfc'), 'wb').write(test)
        print(f'also wrote build/som_desc_{names[n]}.sfc')


if __name__ == '__main__':
    main()
