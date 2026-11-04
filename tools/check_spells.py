"""Compare the spell lists in classes_capstones.txt with the game's own level-up spell table
($D1:BCC0), which the level-up info panel reads at run time (src/bars.asm, LvSpells).

The game (D0:DFEA / E007 / E02B) reads a class's list at $D1:BCC0 + make_levelinfo.list_offsets():
  base   char*$18                    6 entries
  second $90 + (char*2 + path)*$2C   11 entries
  final  $2A0 + (char*4 + path)*$30  12 entries (path: LL LD DL DD)
Entry: [target type: 1 one, 2 all (#), 3 one or all (*), 4 self (^)] [stat << 5 | value: stat 1 STR
.. 6 LUK, 0 = no stat needed] [spell it replaces, or 0] [spell id].
The doc lists Kevin's dark final classes as Dervish, Death Hand; the game's paths are Death Hand
(DL), Dervish (DD).

Usage: python tools/check_spells.py [rom]   -> the differences (doc names via SPELL_NAMES)
"""
import os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_levelinfo as li

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLE = 0x11BCC0          # $D1:BCC0 in the file
MARK = {1: '', 2: '#', 3: '*', 4: '^'}
DOC_ORDER = {1: [0, 1, 2, 3, 4, 6, 5]}     # game class -> doc block (Kevin)
SPELLING = {'Fire Ball': 'Fireball', 'Rock Fall': 'Rockfall'}


def game_list(rom, char, cls):
    """[(stat 0-5, value, name + mark)] of the class's entries that need a stat, sorted."""
    idx = char if cls == 0 else 6 + char * 2 + cls - 1 if cls <= 2 else 18 + char * 4 + cls - 3
    n = 6 if cls == 0 else 11 if cls <= 2 else 12
    off = li.list_offsets()[idx]
    out = []
    for i in range(n):
        t, b, rep, sid = rom[TABLE + off + 4 * i:TABLE + off + 4 * i + 4]
        if t and b >> 5:
            out.append(((b >> 5) - 1, b & 31, li.SPELL_NAMES.get(sid, '?%02X' % sid) + MARK.get(t, '?')))
    return sorted(out)


def class_names():
    txt = open(os.path.join(ROOT, 'classes_capstones.txt'), encoding='utf-8', errors='replace').read()
    heads = re.findall(r'\n([A-Za-z][A-Za-z ]*):\s*\d+/', txt)
    return [heads[k * 7:k * 7 + 7] for k in range(6)]


def main():
    rom = open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build', 'som_test.sfc'), 'rb').read()
    doc = li.class_spells()
    names = class_names()
    diffs = 0
    for char in range(6):
        for cls in range(7):
            blk = DOC_ORDER.get(char, list(range(7)))[cls]
            mine = sorted((st, v, SPELLING.get(n.rstrip('*#^'), n.rstrip('*#^')) + n[len(n.rstrip('*#^')):])
                          for st, v, n in doc[(char, blk)])
            game = game_list(rom, char, cls)
            only_g = [e for e in game if e not in mine]
            only_d = [e for e in mine if e not in game]
            if only_g or only_d:
                print('%s %s:' % (li.CHARS[char], names[char][blk]))
                for st, v, n in only_g:
                    print('   game: %s (%d %s)' % (n, v, li.STAT_ABBR[st]))
                for st, v, n in only_d:
                    print('   doc:  %s (%d %s)' % (n, v, li.STAT_ABBR[st]))
                diffs += len(only_g) + len(only_d)
    print('%d differences' % diffs)


if __name__ == '__main__':
    main()
