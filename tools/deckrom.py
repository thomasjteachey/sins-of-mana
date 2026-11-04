"""Build the Steam Deck ROM: the user's ROM + every add-on patch (see the list below).

Usage: python tools/deckrom.py   (run tools/build.py first)
Writes build/deck/Sins of ManaNORMAL Plus.sfc and prints its MD5.
"""
import hashlib, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ips import apply_ips

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = os.path.join(ROOT, 'build')
rom = bytearray(open(os.path.join(B, 'deck', 'Sins of ManaNORMAL.sfc'), 'rb').read())
for p in ['sinofmana_equip_descriptions.ips', 'no_popup_messages_fixed.ips',
          'sinofmana_revenge_bar.ips', 'sinofmana_enemy_buff_markers.ips', 'sinofmana_party_cast_bar.ips',
          'sinofmana_enemy_cast_bar.ips', 'sinofmana_party_buff_icons.ips', 'sinofmana_levelup_info.ips',
          'sinofmana_shop_descriptions.ips', 'sinofmana_fast_menus.ips']:
    rom, _ = apply_ips(rom, open(os.path.join(B, p), 'rb').read())
out = os.path.join(B, 'deck', 'Sins of ManaNORMAL Plus.sfc')
open(out, 'wb').write(bytes(rom))
print('wrote', os.path.relpath(out, ROOT), hashlib.md5(bytes(rom)).hexdigest())
