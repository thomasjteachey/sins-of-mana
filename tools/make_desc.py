"""Draft src/descriptions.txt: real stats read from the ROM + short effect text.

Usage:  python tools/make_desc.py [--force]
(--force overwrites an existing src/descriptions.txt, losing manual edits)

Stats come from the game's own data in the Sin of Mana ROM:
  weapons  record $D1:6930 + idx*22: +$0D hit rate, +$0E crit rate, +$10 attack
           mod tables (+idx): delay $50:4F00, crit bonus $50:1E00,
                              Lv1 tech bonus $50:2000, counter bonus $50:5000
  others   record $D1:7F30 + idx*26: +$10 evade, +$12 phys def, +$14 magic def
           mod tables (+idx): HP factor $50:3E00, crit resist $50:2900, max MP $50:6000
The item index is the one the game stores for equipped items (character
record +$BC weapon, +$BD.. others); names come from the name tables at
$C4:B31E (weapons) / $C4:B51E (others) and the mod's $53 name bank.
"""
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from build import CATEGORY_SLOTS, LINE_LENGTHS, SAFE_CHARS  # noqa: E402
from ips import apply_ips  # noqa: E402

OUT = os.path.join(ROOT, 'src', 'descriptions.txt')

# Short effect text, keyed by in-game name. Weapons/armor get one line (the
# first line is stats). Fields in {} are filled from the ROM.
WEAPON_FX = {
    'L1 Tech UP': 'Lv1 tech +{l1}, counter +{ct}',
    'Balanced': 'Strong atk 5MP: normal delay',
    'Scapegoat': 'Draws aggro, lowers your Def',
    'YellowDMG heal': 'Yellow damage heals you (LUK)',
    'Poison': 'Chance to poison (LUK)',
    'Silence': 'Chance to silence (LUK)',
    'Super Armor': 'Strong atk wait: no knockback',
    'L2/3 Tech UP': 'Lv2/3 tech damage up',
    'PIE based ATK': 'Attack uses PIE, not STR',
    'AGL based ATK': 'Attack uses AGL, not STR',
    'LUK based ATK': 'Attack uses LUK, not STR',
    'INT based ATK': 'Attack uses INT, not STR',
    'VIT based ATK': 'Attack uses VIT, not STR',
    'PIE based ATK+': 'Attack uses PIE, not STR',
    'AGL based ATK+': 'Attack uses AGL, not STR',
    'LUK based ATK+': 'Attack uses LUK, not STR',
    'INT based ATK+': 'Attack uses INT, not STR',
    'VIT based ATK+': 'Attack uses VIT, not STR',
    'Pure Critical': 'No TP gain, big crit damage',
    'Crit by TP': 'Crit rate +2 per TP',
    'Evasion': 'Evade up',
    'MP Steal': 'Attacks steal MP',
    'Counter UP': 'Counter damage up',
    'Heal UP': 'Stronger Heal Light and items',
    'Magic UP': 'Magic power up',
    'TP gain UP': 'Tech bar fills twice as fast',
    'Defense': 'Def up, attack = your Def',
    'Death Bringer': "Stronger the more you've died",
    'Deathless': 'Atk & Def up while no deaths',
    'HP Steal': 'Attacks steal HP',
    'Pierce Resist': 'Ignores physical resistance',
    'Magitech': 'L2/3 techs hit as INT magic',
    'Exorcise+': 'Turn Undead never deals 0',
    'Subterfuge': "L2/3 tech: +target's attack",
    'Yellow or bust': 'Non-crit normal hits deal 1',
    'CQC Tech': 'L2/3 techs stronger up close',
    'Counter Extend': 'Counters extend counter window',
    'TP Heal Boost': 'Healing up with current TP',
    'L3 Armor Break': 'Lv3 tech lowers Def & MDef',
    'Berserker Wolf': 'Berserker wolf form',
    'Half Vanish+': 'Half Vanish uses maxHP/2',
    'Critical Spell': 'Spells can crit x1.5 (LUK)',
    'EnfeeblingSpell': 'Spell on weakness: counterable',
    'L2/3 Revenge': 'L2/3 techs up below 300 HP',
    'Dual Tech': 'Elem. spells on allies = saber',
    'ExploitWeakness': 'Weakness hits 200% (not 150%)',
    'RTFM': 'More multi-target, Lv2 pierce',
    'AoE Mastery': 'Multi-target spells full dmg',
    'CoDzilla': 'Atk uses PIE, Lv1 tech up',
    'Heal Aura': 'Passive party heal (PIE)',
    'Spell Revenge': 'Spell dmg up with lost HP',
    'Enervate Spawn': 'Enemies -1/8 HP, -2 stats',
    'Saber-Elem. God': 'Non-elem spells use saber elem',
    'Quick Cast': 'Faster casting, magic up a bit',
    'Anti-Magic+': 'Stronger Anti-Magic',
    'Drain Counter': 'Counters heal party HP/MP',
}

ARMOR_FX = {
    'Exp UP': 'Party gains +25% experience',
    'Heal UP': 'Stronger Heal Light and items',
    'High Defense': 'High physical defense',
    'TP on Dodge': '+2 TP when you evade',
    'Undead': 'Heal hurts, resists 5 ailments',
    'Attack UP': 'Attack up, no knockback',
    'Remove Weakness': 'Removes all weaknesses',
    'Magic UP': 'Magic power up',
    'MP Reg. UP': 'MP regeneration +1',
    'BodyStatusRes.': 'Resist petrify, sleep, poison',
    'Element Guard': 'Resist your neutral elements',
    'Auto-Buff': 'Cursed: spells auto-buff',
    'Spell Dodge': 'Cursed: dodge half spell dmg',
    'High Health': 'Huge HP increase',
    'Thorns': 'Reflects 175% physical damage',
    'Invert Buffs': 'Buffs and debuffs swap',
    'Trials Buff': 'Cursed: 2x pow up, no counters',
    'Life Saver': 'On death, MP revives you',
    'Death Bringer': "Cursed: big attack, can't cast",
    'Almighty Magic': 'Cursed: spells +1 lv, no elem',
}

# Helms, accessories, shields: 1-2 lines of effect; the stats line is added
# on line 2 when the item has any.
HELM_FX = {
    'Phys. Defense': ['Physical defense up'],
    'Swift': ['Weapon delay -10, no knockback'],
    'Magic Defense': ['Magic defense up'],
    'MindStatusRes.': ['Resist chibi, moogle, silence'],
    'Attack UP': ['Atk & counter up, no knockback'],
    'Magic UP': ['Magic & damage item power up'],
    'Remove Weakness': ['Removes all weaknesses'],
    'L2/3 Tech UP': ['Lv2/3 tech damage up'],
    'Constant Reg.': ['Cursed: MP regen while casting,', '-1 MP per tick'],
    'Trials Defense': ['Cursed: Def x1.25, no defense', 'vs Lv2/3 techs'],
    'Quick Cast': ['Shorter cast time'],
    'Crit UP': ['Crit rate +8, crit damage +25%'],
}

ACCESSORY_FX = {
    'Atk.&Def. UP': ['Minor attack up'],
    'Fire Weapon': ['Weapon element: fire'],
    'Petrify Res.': ['Resist petrify'],
    'Attack UP': ['Attack up'],
    'Wind Weapon': ['Weapon element: wind'],
    'Critical UP': ['Hit +10, crit +3, crit dmg +15'],
    'Debuff Guard': ['Immune to standard debuffs'],
    'Trials Skill': ['Cursed: no crits either way', 'and no accuracy misses'],
    'Ice Resistance': ['Resist ice, lower defenses'],
    'HP Steal': ['Attacks steal HP'],
    'TP Quick Cast': ['Magic up a bit, TP is spent', 'to shorten casting'],
    'Quick Item': ['Items cost 2 TP (need 4)'],
    'TP by Cast': ['Casting gives 2 TP'],
    'Meta: Pressure': ['Spell upgrade: Pressure'],
    'HP Regeneration': ['Max HP +60, HP regeneration'],
    'Death Bringer': ["Atk, hit, crit up, can't cast", 'Stronger with death score'],
    'Poison Weapon': ['Weapon inflicts poison'],
    'Dark Resistance': ['Resist dark, lower defenses'],
    'Evasion UP': ['Evade up'],
    'Accuracy UP': ['Accuracy +50'],
    'Poison Res.': ['Resist poison'],
    'Spell: Resist': ['Cursed: teaches Resistance'],
    'MP Steal': ['Attacks steal MP'],
    'TP gain UP': ["Tech gain up (doesn't stack)"],
    'Death Res.': ['Immune to death spells,', 'party resists them'],
    'Ailment Res.': ['Cursed: resist all ailments,', 'enemies gain 2 levels'],
    'Wind Resistance': ['Resist wind, lower defenses'],
    'Magic Defense': ['Magic defense up'],
    'Magic UP': ['Magic power up'],
    'Silence Res.': ['Resist silence and', "ignore can't-cast effects"],
    'Trials Element': ['Cursed: no resist/weakness,', 'death score frozen at 1'],
    'Ice Weapon': ['Weapon element: ice'],
    'Break Counter': ['Counters lower enemy defense'],
    'Meta: Sudden': ['Spell upgrade: Sudden,', 'spells use all your MP'],
    'Petrify Weapon': ['Cursed: weapon petrifies,', 'all your damage x0.5'],
    'Fire Resistance': ['Resist fire, lower defenses'],
    'Spell: Regen.': ['Cursed: teaches Regeneration'],
    'Dark Weapon': ['Weapon element: dark'],
    'Power Attack UP': ['Power attack damage up'],
    'Heal UP': ['Stronger Heal Light and items'],
    'Meta: Multi': ['Spell upgrade: multi-target'],
    'Undead': ['Heal hurts, less death penalty'],
    'Meta: Curse': ['Cursed: spell upgrade: Curse'],
    'Tinkle Heal': ['Tinkle Rain also heals 25% HP'],
    'Light Res.': ['Resist light, lower defenses'],
    'Phys. Defense': ['Physical defense up'],
    'Critical Guard': ['Halves enemy crit rate'],
    'Dream Res.': ['Resist sleep, chibikko, moogle'],
    'Meta: LeafCoat': ['Spell upgrade: Leaf Coat'],
    'Earth Weapon': ['Weapon element: earth'],
    'Blood Magic': ['Cast from HP instead of MP,', 'spells cast a bit slower'],
    'Light Weapon': ['Weapon element: light'],
    'TP Regeneration': ['MP regen ticks also give +1 TP'],
    'Earth Res.': ['Resist earth, lower defenses'],
}

SHIELD_FX = {
    'Health UP': ['Max HP up'],
    'Poison Res.': ['Resist poison'],
    'Silence Res.': ['Resist silence'],
    'Petrify Res.': ['Resist petrify'],
    'Dream Res.': ['Resist chibikko and moogle'],
    'Critical Guard': ['Halves enemy crit rate'],
    'Phys. Defense': ['Physical defense up'],
    'Magic Defense': ['Magic defense up'],
    'Evasion UP': ['Evade up'],
}
SHIELD_NOTE = 'Draws aggro'

HEADER = """\
# Equipment descriptions shown in the equip screen's help box.
# Drafted by tools/make_desc.py (stats read from the ROM); edit freely.
#
# Format:
#   == Weapons ==            (also: Helms, Armor, Accessories, Shields)
#   [In-game name]           exactly as the game shows it
#   first line               at most 32 characters
#   second line              at most 30 characters (optional)
#
# The box only has room for 62 characters in total (a limit of the game's text
# tiles), so tools/build.py stops with an error if a line is too long.
# Items with no entry keep the game's normal help text.
#
# Abbreviations
#   Weapons: Atk = attack value, Dly = delay before the next attack,
#            Hit = hit rate, Crit = crit rate / +crit damage bonus
#   Armor:   Def = physical / magic defense value, Eva = evade,
#            CrRes = crit resist, HP = max HP factor
#   Defense values are the item's own numbers; the Defense you see on the
#   status screen also scales with the wearer's stats.
"""


def load_rom():
    clean = open(os.path.join(ROOT, 'Seiken Densetsu 3 (Japan).sfc'), 'rb').read()
    rom, _ = apply_ips(clean, open(os.path.join(ROOT, 'Seiken Densetsu 3 (J)_sinofmana_2060.ips'), 'rb').read())
    return rom


def main():
    if os.path.exists(OUT) and '--force' not in sys.argv:
        sys.exit(f'{OUT} exists; use --force to overwrite (manual edits will be lost)')
    rom = load_rom()

    def word(o): return rom[o] | rom[o + 1] << 8

    def slot_name(slot):
        raw = rom[0x530000 + slot * 16:0x530000 + slot * 16 + 16].split(b'\xff')[0]
        return bytes(c for c in raw if 0x20 <= c < 0x7f).decode('ascii').strip()

    def first_index(table, slots):
        """slot -> first item index whose name maps to that slot"""
        found = {}
        for idx in range(1, 256):
            addr = word(0x040000 + table + idx * 2)
            if not 0x1000 <= addr < 0x3000:
                continue
            s = rom[0x520000 + addr]
            if s in slots and s not in found:
                found[s] = idx
        return found

    out = [HEADER]
    problems = []

    def emit(cat_title, entries):
        out.append(f'\n== {cat_title} ==\n')
        for name, lines in entries:
            for i, ln in enumerate(lines):
                if len(ln) > LINE_LENGTHS[i] or set(ln) - SAFE_CHARS:
                    problems.append(f'{cat_title} [{name}] line {i + 1} ({len(ln)}): {ln}')
            out.append(f'[{name}]\n' + '\n'.join(lines) + '\n')

    # Weapons
    entries = []
    for s, idx in sorted(first_index(0xB31E, set(CATEGORY_SLOTS['weapons'])).items(), key=lambda kv: kv[1]):
        name = slot_name(s)
        rec = 0x116930 + idx * 22
        v = dict(atk=rom[rec + 0x10], hit=rom[rec + 0x0D], cr=rom[rec + 0x0E],
                 dly=rom[0x504F00 + idx], cb=rom[0x501E00 + idx], l1=rom[0x502000 + idx], ct=rom[0x505000 + idx])
        l1 = 'Atk {atk} Dly {dly} Hit {hit} Crit {cr}/+{cb}'.format(**v)
        fx = WEAPON_FX.get(name)
        if fx is None:
            problems.append(f'no weapon effect text for "{name}"')
            fx = ''
        entries.append((name, [l1, fx.format(**v)]))
    emit('Weapons', entries)

    # Armor-type items (helms, armor, accessories, shields share one table)
    other = first_index(0xB51E, set(CATEGORY_SLOTS['helms'] + CATEGORY_SLOTS['armor'] +
                                    CATEGORY_SLOTS['accessories'] + CATEGORY_SLOTS['shields']))

    def stats(idx):
        rec = 0x117F30 + idx * 26
        return dict(eva=rom[rec + 0x10], p=rom[rec + 0x12], m=rom[rec + 0x14],
                    hp=rom[0x503E00 + idx], cres=rom[0x502900 + idx], mp=rom[0x506000 + idx])

    for title, cat, fxmap in (('Helms', 'helms', HELM_FX), ('Armor', 'armor', ARMOR_FX),
                              ('Accessories', 'accessories', ACCESSORY_FX), ('Shields', 'shields', SHIELD_FX)):
        entries = []
        for s in CATEGORY_SLOTS[cat]:
            if s not in other:
                continue
            name, v = slot_name(s), stats(other[s])
            fx = fxmap.get(name)
            if fx is None:
                problems.append(f'no {cat} effect text for "{name}"')
                fx = [''] if cat != 'armor' else ''
            if cat == 'armor':
                lines = ['Def {p}/{m} Eva {eva} CrRes {cres} HP{hp}%'.format(**v), fx]
            else:
                parts = [f'{k} +{v[f]}' for k, f in (('Def', 'p'), ('MDef', 'm'), ('Eva', 'eva'), ('MP', 'mp')) if v[f]]
                if cat == 'shields':
                    parts.append(SHIELD_NOTE)
                lines = list(fx)
                if parts:
                    extra = '  '.join(parts)
                    if len(lines) == 1:
                        lines.append(extra)
                    elif len(lines[1]) + 2 + len(extra) <= LINE_LENGTHS[1]:
                        lines[1] += '  ' + extra
                    else:
                        problems.append(f'{cat} [{name}] has no room for its stats: {extra}')
            entries.append((name, lines))
        emit(title, entries)

    if problems:
        print('\n'.join('problem: ' + p for p in problems))
    open(OUT, 'w', encoding='utf-8').write(''.join(out))
    print(f'wrote {os.path.relpath(OUT, ROOT)}')


if __name__ == '__main__':
    main()
