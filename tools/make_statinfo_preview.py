"""Preview of the level-up info panel: writes build/probe_statinfo_cfg.lua (glyph tiles and
panel cells) for tests/probe_statinfo_preview.lua, which pokes them straight into VRAM.

Usage: python tools/make_statinfo_preview.py CHAR STAT [LABEL]
  CHAR 0-5 (Duran Kevin Hawk Angela Carlie Lise), STAT 0-5 (Strength .. Luck)
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# New punctuation in the HUD font's style (3 = white body, 2 = gold edge, 1 = dark outline).
GLYPHS = {
    ':': ['........', '.331....', '.221....', '.111....', '.331....', '.221....', '.111....', '........'],
    ',': ['........', '........', '........', '........', '.331....', '.331....', '..21....', '.21.....'],
    '.': ['........', '........', '........', '........', '........', '.331....', '.221....', '.111....'],
    '/': ['......22', '.....331', '....331.', '...331..', '..331...', '.331....', '221.....', '11......'],
    '%': ['22....22', '331..331', '11..331.', '...331..', '..331...', '.331..22', '221..331', '11....11'],
    '(': ['....22..', '...331..', '..331...', '..331...', '..331...', '..331...', '...221..', '....11..'],
    ')': ['..22....', '..331...', '...331..', '...331..', '...331..', '...331..', '..221...', '..11....'],
}
GLYPH_BASE = 0x0DD
GLYPH_TILE = {ch: GLYPH_BASE + i for i, ch in enumerate(GLYPHS)}

STAT_TEXT = [                    # two lines each, at most 30 characters
    ['Strength: weapon/tech attack,', 'strong attack, +2 max HP/point'],
    ['Agility: hit, evade, cast time', 'Lv1 techs, jutsu, cooldown 18+'],
    ['Vitality: physical defense,', 'jutsu/trap def, +1.5 max HP/pt'],
    ['Intelligence: elemental spell', 'damage, Lv2/3 techs, MP, regen'],
    ['Spirit: magic def, healing,', 'summon/light/dark spell damage'],
    ['Luck: crits (chance, damage,', 'resist), status, drops, traps'],
]
CAP = [
    ['enemies spawn with -15 p.def and m.def',
     'saber spells add 20% attack instead of 10% (party)',
     'each MP regen tick also restores 15 HP',
     '+7 p.def/m.def and +20 HP per cursed accessory worn',
     '+10 max MP',
     'party crit resistance +15%'],
    ['enemies spawn with -15 p.def and m.def',
     'status weapon hits: +30 damage (+40 crit), even vs immune',
     'draws enemy aggro',
     'saber spells add 20% attack instead of 10% (party)',
     'Heal Light also gives +1 TP',
     'party takes less damage from critical hits'],
    ['enemies spawn with -20 evade',
     '+40% counter damage (party)',
     '+20 evade',
     'status weapon hits: +30 damage (+40 crit), even vs immune',
     'Lv2/3 techs: party gets your saber, pseudo saber real unless resisted',
     'ignores monster crit resistance, critical damage +20%'],
    ['adds a fraction of weapon damage to spell damage',
     'party casts 20% faster',
     'fire/ice/wind/earth spells heal the party by 50 HP',
     'spells pierce 35 m.def',
     '+7 p.def/m.def and +20 HP per cursed accessory worn',
     'weapons use LUK instead of their regular stat'],
    ['Lv2/3 techs inflict wood coat unless fire saber is active',
     'enemies spawn with -20 evade',
     '+50 max HP, +10 p.def and m.def',
     'light and dark spells deal more damage',
     'Tinkle Rain also heals 25% of caster max HP if it cures a status',
     'party spells cost 20% less MP (min 1), shown cost stays'],
    ['+20% attack, but non-critical normal attacks deal half damage',
     'weapon cooldown -7 (party)',
     'enemies spawn with -15 attack',
     'can equip any weapon and armor, even class-locked',
     'Heal Light also gives +1 TP',
     'party takes 1/8 less damage from spells'],
]
WIDTH = 30


def wrap(text, width):
    lines, cur = [], ''
    for word in text.split(' '):
        if not cur:
            cur = word
        elif len(cur) + 1 + len(word) <= width:
            cur += ' ' + word
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    return lines


def tile(ch):
    if ch == ' ':
        return 0x0FF
    if 'A' <= ch <= 'Z':
        return 0x04A + ord(ch) - 65
    if 'a' <= ch <= 'z':
        return 0x064 + ord(ch) - 97
    if '0' <= ch <= '9':
        return 0x080 + ord(ch) - 48
    if ch == '+':
        return 0x03D
    if ch == '-':
        return 0x03E
    if ch == '!':
        return 0x07E
    if ch == '?':
        return 0x07F
    if ch == "'":
        return 0x08A
    return GLYPH_TILE[ch]


def panel(char, stat, label):
    head = STAT_TEXT[stat][0].split(':', 1)[0]
    lines = list(STAT_TEXT[stat])
    assert all(len(line) <= WIDTH for line in lines), lines
    cap = wrap(label + ' ' + CAP[char][stat], WIDTH)
    assert len(cap) <= 3, cap
    while len(cap) < 3:
        cap.append('')
    cells = []
    for i, line in enumerate(lines + cap):
        row = []
        for j, ch in enumerate(line.ljust(WIDTH)):
            p = 4
            if i == 0 and j <= len(head):
                p = 3                    # stat name in the window's red
            if i == 2 and j < len(label):
                p = 1                    # capstone label in green
            row.append(0x2000 | (p << 10) | tile(ch))
        cells.append(row)
    return lines + cap, cells


def encode(rows):
    out = []
    for row in rows:
        p0 = p1 = 0
        for ch in row:
            c = 0 if ch == '.' else int(ch)
            p0 = (p0 << 1) | (c & 1)
            p1 = (p1 << 1) | (c >> 1)
        out += [p0, p1]
    return out


if __name__ == '__main__':
    char, stat = int(sys.argv[1]), int(sys.argv[2])
    label = sys.argv[3] if len(sys.argv) > 3 else 'Lv60 if highest:'
    text, cells = panel(char, stat, label)
    for line in text:
        print('|' + line.ljust(WIDTH) + '|')
    lua = ['GLYPHS_G = {']
    for ch, rows in GLYPHS.items():
        lua.append('  {%d, {%s}},' % (GLYPH_TILE[ch], ', '.join(str(b) for b in encode(rows))))
    lua.append('}')
    lua.append('PANEL_G = {')
    for r, row in enumerate(cells):
        lua.append('  {%d, {%s}},' % (r + 1, ', '.join(str(v) for v in row)))
    lua.append('}')
    open(os.path.join(ROOT, 'build', 'probe_statinfo_cfg.lua'), 'w').write('\n'.join(lua) + '\n')
