"""Bar graphics for src/bars.asm, drawn as pixel art and written as BG3 2bpp tiles.

Colours (the HUD's BG3 palettes): . = transparent, 1 = dark outline (the HUD's
dark brown), 2 = fill, 3 = highlight. Each bar is 4 pixels tall; tiles come in
two sets: the "upper" set draws in pixel rows 0-3 of the tile, the "lower" set
in rows 4-7, so two bars can share one BG3 map row (see bars.asm).

Then 9 stat icons for the party buff tags (see ICONS), then punctuation glyphs for the
level-up info panel (see GLYPHS).

Per bar set (10 tiles, in this order):
  0-4  middle cells filled 0, 2, 4, 6, 8 pixels from the left
  5    left end cap (rounded edge)
  6    left end cap with the spell marker (cast bars)
  7    left end cap with an up arrow (enemy has raised stats)
  8    left end cap with a down arrow (enemy has lowered stats)
  9    right end cap (rounded edge)

Usage (called by tools/build.py): write(path) -> asar source with BarGfx/BarGfxEnd.
"""

FILL = 8


def middle(f):
    return ['11111111',
            '3' * f + '1' * (FILL - f),     # highlight row of the fill
            '2' * f + '1' * (FILL - f),     # base row
            '11111111']


CAP_L = ['........',
         '.......1',
         '.......1',
         '........']
CAP_CAST = ['..131...',                       # small diamond
            '.13331.1',
            '.12221.1',
            '..121...']
CAP_UP = ['..131...',                         # arrow pointing up
          '.12221.1',
          '12222211',
          '1111111.']
CAP_DOWN = ['1111111.',                       # arrow pointing down
            '12222211',
            '.12221.1',
            '..131...']
CAP_R = ['........',
         '1.......',
         '1.......',
         '........']

TILES = [middle(f) for f in (0, 2, 4, 6, 8)] + [CAP_L, CAP_CAST, CAP_UP, CAP_DOWN, CAP_R]
BLANK = ['........'] * 4

# Party buff icons: one 8x8 tile per stat (outline 1, fill 2, highlight 3).
# The palette shows the direction: green raised, red lowered, gold (Lucid Barrier).
# Order = TagDefs in bars.asm.
ICONS = [
    ('ATK', [  # sword: attack power
        '.....111',
        '....1331',
        '...13331',
        '1.13331.',
        '11331...',
        '.121....',
        '1211....',
        '11......',
    ]),
    ('DEF', [  # shield: defense power
        '.111111.',
        '13333331',
        '13222231',
        '13222231',
        '.132231.',
        '.132231.',
        '..1331..',
        '...11...',
    ]),
    ('MAG', [  # wand with a sparkle: magic effectiveness
        '....1.1.',
        '.....3..',
        '....333.',
        '...1.3..',
        '..121...',
        '.121....',
        '121.....',
        '11......',
    ]),
    ('MDF', [  # shield with a sparkle: magic defense
        '.11111.3',
        '13333133',
        '1322231.',
        '1322231.',
        '.13231..',
        '.13231..',
        '..131...',
        '...1....',
    ]),
    ('HIT', [  # reticle: hit rate
        '..1331..',
        '.1....1.',
        '1..33..1',
        '3.3113.3',
        '3.3113.3',
        '1..33..1',
        '.1....1.',
        '..1331..',
    ]),
    ('EVA', [  # boot, toe to the right: evade rate
        '.11111..',
        '.13331..',
        '.13331..',
        '.13331..',
        '.133311.',
        '.1333331',
        '.1222221',
        '.1111111',
    ]),
    ('HP', [  # heart: maximum HP
        '.11..11.',
        '13311331',
        '13333331',
        '13333321',
        '.133321.',
        '..1321..',
        '...11...',
        '........',
    ]),
    ('MP', [  # drop: maximum MP
        '...1....',
        '..131...',
        '..131...',
        '.13331..',
        '1333331.',
        '1332231.',
        '.12221..',
        '..111...',
    ]),
    ('BAR', [  # ghost: Lucid Barrier ("body became transparent")
        '..1111..',
        '.133331.',
        '13133131',
        '13333331',
        '13333331',
        '13333331',
        '13133131',
        '1.11.1.1',
    ]),
]
TAG_TILES = [rows for _, rows in ICONS]
TAGS = [name for name, _ in ICONS]

def encode(rows):
    """8 rows of 8 colour characters -> 16 bytes of SNES 2bpp (plane 0, plane 1 per row)."""
    out = []
    for row in rows:
        assert len(row) == 8, row
        p0 = p1 = 0
        for ch in row:
            c = 0 if ch == '.' else int(ch)
            p0 = (p0 << 1) | (c & 1)
            p1 = (p1 << 1) | (c >> 1)
        out += [p0, p1]
    return out


# Punctuation the HUD font lacks, for the level-up info panel (tools/make_levelinfo.py),
# in the font's style: 3 = white body, 2 = gold edge, 1 = dark outline. Tiles $0DD-$0E8.
GLYPHS = [
    (':', ['........', '.331....', '.221....', '.111....', '.331....', '.221....', '.111....', '........']),
    (',', ['........', '........', '........', '........', '.331....', '.331....', '..21....', '.21.....']),
    ('.', ['........', '........', '........', '........', '........', '.331....', '.221....', '.111....']),
    ('/', ['......22', '.....331', '....331.', '...331..', '..331...', '.331....', '221.....', '11......']),
    ('%', ['22....22', '331..331', '11..331.', '...331..', '..331...', '.331..22', '221..331', '11....11']),
    ('(', ['....22..', '...331..', '..331...', '..331...', '..331...', '..331...', '...221..', '....11..']),
    (')', ['..22....', '..331...', '...331..', '...331..', '...331..', '...331..', '..221...', '..11....']),
    ('&', ['..2221..', '.331.31.', '.331.31.', '..331...', '.33133.3', '331.331.', '.22221.2', '..1111.1']),
    ('=', ['........', '33333331', '11111111', '........', '33333331', '11111111', '........', '........']),
    ('*', ['...21...', '.31313..', '..3331..', '.31313..', '...31...', '...11...', '........', '........']),
    ('#', ['.21.21..', '3333331.', '.31.31..', '.31.31..', '3333331.', '.31.31..', '.11.11..', '........']),
    ('^', ['...21...', '..3131..', '.31..31.', '.11..11.', '........', '........', '........', '........']),
]
GLYPH_BASE = 0x0DD                 # right after the 9 icons ($0D4-$0DC)


def tiles():
    upper = [encode(t + BLANK) for t in TILES]
    lower = [encode(BLANK + t) for t in TILES]
    return upper + lower + [encode(t) for t in TAG_TILES] + [encode(g) for _, g in GLYPHS]


def write(path):
    lines = ['; generated by tools/make_bargfx.py - edit the pixel art there',
             'BarGfx:']
    for i, t in enumerate(tiles()):
        what = ('upper %d' % i) if i < 10 else ('lower %d' % (i - 10)) if i < 20 else \
            ('icon %s' % TAGS[i - 20]) if i < 20 + len(TAGS) else \
            ('glyph %s' % GLYPHS[i - 20 - len(TAGS)][0])
        lines.append('\tdb ' + ', '.join('$%02X' % b for b in t) + '   ; ' + what)
    lines.append('BarGfxEnd:')
    open(path, 'w').write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    import os, sys
    write(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'build', 'bargfx.asm'))
