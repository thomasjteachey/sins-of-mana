"""Texts for the level-up info panel (src/bars.asm, LevelPanel), as BG3 HUD-font tile numbers.

The panel is 5 rows x 30 cells at the top of the screen while the level-up stat window is up:
  rows 1-2  what the highlighted stat does (STAT_TEXT, from README.txt "Character Stats")
  row 3     the character's current-class spells that use the stat, read at run time from the
            game's own level-up table ($D1:BCC0, see LvSpells): "Next: <spell> at <n> (+k)",
            "Learns <spell> now!", "All <stat> spells reached", "No <stat> spells in this class",
            "Next <stat> spell needs a spirit", "Spell list full (10 known)"
  rows 4-5  that character's Lv60 capstone for the stat (CAP), after a 16-cell label:
            "Lv60 if highest:" or "Lv60 (on track):"
Written to build/levelinfo.asm (called by tools/build.py):
  LvStatText  6 x 60 bytes   two rows of 30 cells per stat (Strength .. Luck)
  LvNameLen   6 bytes        cells of "Name:" at the start of each (drawn in red)
  LvLabels    2 x 16 bytes   "Lv60 if highest:", "Lv60 (on track):"
  LvAscii     96 bytes       ASCII $20-$7F -> tile, for the shop panel (descriptions from desc.asm)
  LvCapText   36 x 44 bytes  per character (Duran Kevin Hawk Angela Carlie Lise) x stat:
                             cells 16-29 of row 4, then row 5 (30 cells)
  LvFixed     19 x 30 bytes  fixed spell lines: list full; per stat "No .."; "All .."; "Next .. spirit"
  LvFixedLab  19 bytes       cells of each drawn in green
  LvSpellPtr  words          per spell id: offset of its name in LvSpellNames (length byte + tiles)
  LvListOfs   42 words       offset in the game's table of each class's list, in the game's order:
                             base per character, second per (character, path), final per
                             (character, path LL LD DL DD)
  LvMarks     3 bytes        tiles of the target marks # (all), * (one or all), ^ (self)
  LvTxt*                     pieces of the "Next:" / "Learns" lines (length byte + tiles)
Spell names by id (SPELL_NAMES) are the reference doc's (classes_capstones.txt), matched to the
game's table by tools/check_spells.py.
"""
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_bargfx import GLYPHS, GLYPH_BASE

WIDTH = 30
LABEL = 16
STAT_TEXT = [                    # two lines each, at most 30 characters
    ['Strength: weapon/tech attack,', 'strong attack, +2 max HP/point'],
    ['Agility: hit, evade, cast time', 'Lv1 techs, jutsu, cooldown 18+'],
    ['Vitality: physical defense,', 'jutsu/trap def, +1.5 max HP/pt'],
    ['Intelligence: elemental spell', 'damage, Lv2/3 techs, MP, regen'],
    ['Spirit: magic def, healing,', 'summon/light/dark spell damage'],
    ['Luck: crits (chance, damage,', 'resist), status, drops, traps'],
]
LABELS = ['Lv60 if highest:', 'Lv60 (on track):']
STATUS_HIT = 'status weapon hits always +30 (crit +40)'
SABER_20 = 'party saber spells +20% atk (not +10%)'
CURSED = 'each cursed acc: +7 p.def/m.def, +20 HP'
CAP = [                          # at most 13 + 30 characters after the label (two rows)
    ['enemies spawn with -15 p.def & m.def', SABER_20, 'MP regen ticks also heal 15 HP',
     CURSED, '+10 max MP', 'party crit resistance +15%'],                                   # Duran
    ['enemies spawn with -15 p.def & m.def', STATUS_HIT, 'draws enemy aggro', SABER_20,
     'Heal Light also gives +1 TP', 'party takes less damage from crits'],                  # Kevin
    ['enemies spawn with -20 evade', '+40% counter damage (party)', '+20 evade', STATUS_HIT,
     'Lv2/3 techs spread saber, pseudo = real',
     'crit dmg +20%, ignore monster crit res'],                                            # Hawk
    ['adds part of weapon damage to spells', 'party casts 20% faster',
     'party +50 HP on fire/ice/wind/earth spells', 'spells pierce 35 m.def', CURSED,
     'weapons use LUK instead of usual stat'],                                             # Angela
    ['Lv2/3 techs wood coat, unless fire saber', 'enemies spawn with -20 evade',
     '+50 max HP, +10 p.def & m.def', 'light & dark spells deal more damage',
     'Tinkle Rain cure also heals 25% max HP',
     'party spells -20% MP (min 1), not shown'],                                            # Carlie
    ['+20% atk, non-crit normal hits half dmg', 'weapon cooldown -7 (party)',
     'enemies spawn with -15 attack', 'equip any weapon & armor, even locked',
     'Heal Light also gives +1 TP', 'party takes 1/8 less spell damage'],                   # Lise
]
STAT_ABBR = ['STR', 'AGL', 'VIT', 'INT', 'SPI', 'LUK']
CHARS = ['Duran', 'Kevin', 'Hawk', 'Angela', 'Charlie', 'Lise']
STAT_OF = {'STR': 0, 'AGL': 1, 'VIT': 2, 'INT': 3, 'PIE': 4, 'LUCK': 5, 'LUK': 5}
FIXED = [('Spell list full (10 known)', 15)] + \
        [('No %s spells in this class' % a, 2) for a in STAT_ABBR] + \
        [('All %s spells reached' % a, 3) for a in STAT_ABBR] + \
        [('Next %s spell needs a spirit' % a, 4) for a in STAT_ABBR]
# Spell ids of the game's level-up table ($D1:BCC0) -> the reference doc's names (without the
# target marks, which come from the table).
SPELL_NAMES = {
    0x01: 'Diamond Missile', 0x02: 'Earth Quake', 0x03: 'Stone Cloud', 0x04: 'Protect Up',
    0x05: 'Speed Down', 0x06: 'Diamond Saber', 0x07: 'Airblast', 0x08: 'Thunderstorm',
    0x09: 'Stun Wind', 0x0A: 'Speed Up', 0x0B: 'Protect Down', 0x0C: 'Thunder Saber',
    0x0D: 'Ice Smash', 0x0E: 'Mega Splash', 0x0F: 'Cold Blaze', 0x10: 'Mind Up',
    0x11: 'Power Down', 0x12: 'Ice Saber', 0x13: 'Fireball', 0x14: 'Explode', 0x15: 'Blaze Wall',
    0x16: 'Power Up', 0x17: 'Mind Down', 0x18: 'Flame Saber', 0x19: 'Evil Gate', 0x1A: 'Dark Force',
    0x1B: 'Annihilator', 0x1C: 'Anti-Magic', 0x1D: 'Black Curse', 0x1E: 'Dark Saber',
    0x1F: 'Holy Ball', 0x20: 'Saint Beam', 0x21: 'Heal Light', 0x22: 'Magic Shield',
    0x23: 'Tinkle Rain', 0x24: 'Saint Saber', 0x25: 'Lunatic', 0x26: 'Half Vanish',
    0x27: 'Body Change', 0x28: 'Life Booster', 0x29: 'Energy Ball', 0x2A: 'Moon Saber',
    0x2B: 'Sleep Flower', 0x2C: 'Poison Bubble', 0x2D: 'Transshape', 0x2E: 'Aura Wave',
    0x30: 'Leaf Saber', 0x31: 'Analyse', 0x32: 'Exorcise', 0x33: 'Demon Breath',
    0x34: 'Rainbow Dust', 0x35: 'Ancient', 0x38: 'Freya', 0x39: 'Marduke', 0x3A: 'Jormungand',
    0x3B: 'Lamia Naga', 0x3C: 'Unicorn Head', 0x3D: 'Machine Golem', 0x3E: 'Ghoul', 0x3F: 'Ghost',
    0x40: 'Gremlin', 0x41: 'Great Demon', 0x42: 'Earth Jutsu', 0x43: 'Thunder Jutsu',
    0x44: 'Water Jutsu', 0x45: 'Fire Jutsu', 0x46: 'Arrows', 0x47: 'Spikes', 0x48: 'Rockfall',
    0x49: 'Land Mine', 0x4A: 'Poison Breath', 0x4B: 'Fire Breath', 0x4C: 'Blow Needles',
    0x4D: 'Deadly Weapon', 0x4E: 'Triple Spell', 0x7B: 'Shuriken', 0x7E: 'Silver Dart',
    0x7F: 'Cutter Missile', 0x80: 'Crescent', 0x81: 'Rocket Launcher', 0x82: 'Axe Bomber',
    0x83: 'Grenade Bomb', 0x93: 'Black Rain', 0x95: 'Ghost Road',
}


def list_offsets():
    """Offsets of the class lists in the game's table, as D0:DFEA / E007 / E02B compute them."""
    return ([c * 0x18 for c in range(6)] +
            [0x90 + k * 0x2C for k in range(12)] +
            [0x2A0 + k * 0x30 for k in range(24)])
TXT = {'Next': 'Next: ', 'At': ' at ', 'Learns': 'Learns ', 'Now': ' now!', 'More': ' (+', 'Close': ')'}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def class_spells():
    """classes_capstones.txt -> {(char 0-5, class 0-6): [(stat, threshold, name), ...]} sorted."""
    import re
    txt = open(os.path.join(ROOT, 'classes_capstones.txt'), encoding='utf-8', errors='replace').read()
    starts = [txt.index('\n' + c + '\n') for c in CHARS] + [len(txt)]
    out = {}
    for ci in range(6):
        sec = txt[starts[ci]:starts[ci + 1]]
        blocks = re.split(r'\n(?=[A-Za-z][A-Za-z ]*:\s*\d)', sec)[1:]
        assert len(blocks) == 7, (CHARS[ci], len(blocks))
        for k, b in enumerate(blocks):
            body = b.split('spell list:', 1)[1] if 'spell list:' in b else ''
            body = body.split('\n\n', 1)[0].split('\ncapstones')[0]
            ents = re.findall(r"([A-Za-z][A-Za-z' \-]*?)([*#^]?)\s*\((\d+)\s+(STR|AGL|VIT|INT|PIE|LUCK|LUK)"
                              r"(?:,[^)]*)?\)", body)
            lst = []
            for name, mark, t, st in ents:
                name = name.strip().replace('Cresent', 'Crescent')
                lst.append((STAT_OF[st], int(t), name + mark))
            out[(ci, k)] = sorted(lst)
    return out


GLYPH_TILE = {ch: GLYPH_BASE + i for i, (ch, _) in enumerate(GLYPHS)}


def tile(ch):
    if ch == ' ':
        return 0x0FF
    if 'A' <= ch <= 'Z':
        return 0x04A + ord(ch) - 65
    if 'a' <= ch <= 'z':
        return 0x064 + ord(ch) - 97
    if '0' <= ch <= '9':
        return 0x080 + ord(ch) - 48
    fixed = {'+': 0x03D, '-': 0x03E, '!': 0x07E, '?': 0x07F, "'": 0x08A}
    if ch in fixed:
        return fixed[ch]
    return GLYPH_TILE[ch]


def wrap(text, widths):
    """Greedy word wrap into len(widths) lines of the given widths; error if it doesn't fit."""
    lines, cur, k = [], '', 0
    for word in text.split(' '):
        if cur and len(cur) + 1 + len(word) <= widths[k]:
            cur += ' ' + word
            continue
        if cur or len(word) > widths[k]:         # next line (a long first word skips line 0)
            lines.append(cur)
            k += 1
            if k >= len(widths) or len(word) > widths[k]:
                raise ValueError('does not fit: %r' % text)
        cur = word
    lines.append(cur)
    return lines + [''] * (len(widths) - len(lines))


def cells(text, n):
    assert len(text) <= n, text
    return [tile(ch) for ch in text.ljust(n)]


def capstone_cells(text):
    # row 4 holds the label (16 cells), a space, then 13 cells of text; row 5 holds 30
    a, b = wrap(text, [WIDTH - LABEL - 1, WIDTH])
    return cells(' ' + a, WIDTH - LABEL) + cells(b, WIDTH)


def lstr(text):
    """length byte + tiles"""
    return [len(text)] + [tile(ch) for ch in text]


def write(path):
    out = ['; generated by tools/make_levelinfo.py - edit the texts there']
    out.append('LvStatText:')
    for name, (a, b) in zip(('Strength', 'Agility', 'Vitality', 'Intelligence', 'Spirit', 'Luck'), STAT_TEXT):
        out.append('\tdb ' + ', '.join('$%02X' % t for t in cells(a, WIDTH) + cells(b, WIDTH)) + '   ; ' + name)
    out.append('LvNameLen:')
    out.append('\tdb ' + ', '.join('%d' % (len(a.split(':')[0]) + 1) for a, _ in STAT_TEXT))
    out.append('LvLabels:')
    for label in LABELS:
        assert len(label) == LABEL, label
        out.append('\tdb ' + ', '.join('$%02X' % t for t in cells(label, LABEL)) + '   ; ' + label)
    out.append('LvAscii:                 ; shop panel: ASCII $20-$7F -> tile ($FF = blank / not in the font)')
    row = []
    for c in range(0x20, 0x80):
        try:
            row.append(tile(chr(c)))
        except KeyError:
            row.append(0x0FF)
    for k in range(0, 96, 16):
        out.append('	db ' + ', '.join('$%02X' % t for t in row[k:k + 16]))
    out.append('LvCapText:')
    for who, caps in zip(('Duran', 'Kevin', 'Hawk', 'Angela', 'Carlie', 'Lise'), CAP):
        for stat, text in zip(('STR', 'AGL', 'VIT', 'INT', 'PIE', 'LUK'), caps):
            data = capstone_cells(text)
            assert len(data) == 44
            out.append('\tdb ' + ', '.join('$%02X' % t for t in data) + '   ; %s %s' % (who, stat))
    out.append('LvFixed:')
    for text, _ in FIXED:
        out.append('\tdb ' + ', '.join('$%02X' % t for t in cells(text, WIDTH)) + '   ; ' + text)
    out.append('LvFixedLab:')
    out.append('\tdb ' + ', '.join('%d' % n for _, n in FIXED))
    for key, text in TXT.items():
        out.append('LvTxt%s:' % key)
        out.append('\tdb ' + ', '.join('$%02X' % t for t in lstr(text)) + '   ; "%s"' % text)
    # names by spell id (0 = empty name); the longest with its mark must fit "Next: " + name
    # + " at nn" in 30 cells
    assert max(len(n) for n in SPELL_NAMES.values()) <= 15, max(SPELL_NAMES.values(), key=len)
    out.append('LvSpellPtr:                ; per spell id: offset in LvSpellNames')
    off, ptrs, blob = 1, [], [0]
    for sid in range(max(SPELL_NAMES) + 1):
        if sid in SPELL_NAMES:
            ptrs.append(off)
            b = lstr(SPELL_NAMES[sid])
            blob += b
            off += len(b)
        else:
            ptrs.append(0)
    for k in range(0, len(ptrs), 12):
        out.append('\tdw ' + ', '.join('$%04X' % v for v in ptrs[k:k + 12]))
    out.append('LvSpellNames:')
    for k in range(0, len(blob), 24):
        out.append('\tdb ' + ', '.join('$%02X' % v for v in blob[k:k + 24]))
    out.append('LvListOfs:                 ; game table ($D1:BCC0) offsets: base x6, second x12, final x24')
    ofs = list_offsets()
    for k in range(0, len(ofs), 6):
        out.append('\tdw ' + ', '.join('$%04X' % v for v in ofs[k:k + 6]))
    out.append('LvMarks:                   ; target marks of types 2 (all), 3 (one or all), 4 (self)')
    out.append('\tdb ' + ', '.join('$%02X' % tile(c) for c in '#*^'))
    open(path, 'w').write('\n'.join(out) + '\n')


if __name__ == '__main__':
    for who, caps in zip(('Duran', 'Kevin', 'Hawk', 'Angela', 'Carlie', 'Lise'), CAP):
        for stat, text in zip(('STR', 'AGL', 'VIT', 'INT', 'PIE', 'LUK'), caps):
            a, b = wrap(text, [WIDTH - LABEL - 1, WIDTH])
            print('%-6s %s |%s %s|%s|' % (who, stat, LABELS[0], a.ljust(13), b.ljust(30)))
    write(sys.argv[1] if len(sys.argv) > 1 else
          os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build', 'levelinfo.asm'))
