# Sin of Mana add-on patches

Optional IPS patches for **Sin of Mana 2.060** (Seiken Densetsu 3 mod). Apply them to a
ROM that already has the 2.060 patch: `Seiken Densetsu 3 (Japan).sfc` (unheadered, MD5
`58ebd7cbf28ceadc03aec4f448956a0b`) + `Seiken Densetsu 3 (J)_sinofmana_2060.ips`, which
gives a 6 MB ExHiROM file (MD5 `1f111cc4630ec2e39c6851b6548dba27`). They also work on top
of the mod's Normal difficulty and bonus fight patches.

Pick any mix and apply in any order. Only one combination has a requirement:
`sinofmana_shop_descriptions.ips` needs `sinofmana_equip_descriptions.ips`.

## The patches

| Patch | What it does |
|---|---|
| `sinofmana_equip_descriptions.ips` | The EQUIP screen's help box describes the highlighted weapon or armor (stats and special effects), and updates when the slot cursor moves. Also fixes garbage room tiles that could show after leaving the equip screen. |
| `no_popup_messages_fixed.ips` | Hides the stat-change popups ("Attack up", ...) and status ailment messages. Fixed version of `misc_patches/no_popup_messages.ips`, which also stopped stat buffs (Power Up, Protect Up, Life Booster, Magic Shield, ...) from doing anything. Also repairs a ROM that already has the old patch. |
| `sinofmana_fast_menus.ips` | Faster main menu and screen transitions: shorter fades, no long pause on black, faster graphics and text loading, faster submenu slides. Same screens, same result. |
| `sinofmana_revenge_bar.ips` | A bar under each enemy showing how close it is to its revenge (counter) attack. |
| `sinofmana_enemy_buff_markers.ips` | Up / down arrows beside the enemy's bar for raised or lowered stats. |
| `sinofmana_party_cast_bar.ips` | A bar under a party member while they cast, filling as the spell gets ready. |
| `sinofmana_enemy_cast_bar.ips` | The same for enemies. |
| `sinofmana_party_buff_icons.ips` | Buff / debuff icons beside each party member's HUD. |
| `sinofmana_levelup_info.ips` | At the level-up stat choice, a panel shows what the highlighted stat does, the next spell it unlocks in the current class, and the character's Lv60 capstone for it. |
| `sinofmana_shop_descriptions.ips` | The equipment descriptions in a shop's buy / sell ring, in the same top panel. |
| `sinofmana_enemy_weaknesses.ips` | While you pick a target, the lines under the target bar list the enemy's weak and resisted elements (weak / drain / repel / void / half). |

The eight bar / panel patches share one engine: each carries all of it plus its own
on/off switch, so they never conflict with each other.

## Files

- `patches/`: the IPS files.
- `ADDRESSES.md`: every ROM range each patch writes (hooks, data edits, free space used),
  plus the RAM, VRAM and DMA they use.
- `TECHNICAL_NOTES.md`: research notes: how each feature works and what the hooked code does.

## Credits

Made by ttopper, written with Claude (Anthropic's AI assistant). Sin of Mana by Praetarius5018.
Enemy weakness data from the mod's `monster_bosses.xls`.
