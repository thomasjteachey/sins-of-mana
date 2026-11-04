"""Spell-spam soak test: chain segments of N casts, saving a state after each.

Usage: python tools/spam.py START_STATE SEGMENTS [CASTS_PER_SEGMENT] [SPELL_ENTRY_HEX]
Each segment: refill HP/MP, open the ring menu, cast, wait. Prints how many casts
started/fired per segment and saves build/states/soak_<n>.mss + build/shots/soak_<n>.png.
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
start, segs = sys.argv[1], int(sys.argv[2])
per = int(sys.argv[3]) if len(sys.argv) > 3 else 40
spell = sys.argv[4] if len(sys.argv) > 4 else '13'
first = int(start.split('_')[1]) + 1 if start.startswith('soak_') else 1
state = start
for s in range(first, first + segs):
    steps = [f'poke:7FEEA5={spell}', 'w2']
    for _ in range(per):
        steps += ['poke:7FEDF2=58,00', 'poke:7FEDF4=63,00', 'poke:7FEE04=63,00', 'poke:7FD9F2=58,00',
                  'x', 'w40', 'a', 'w20', 'a', 'w150']
    steps += [f'save:soak_{s}', f'shot:soak_{s}', 'poke:7E1FFF=AA', 'w2']
    r = subprocess.run([sys.executable, '-I', os.path.join(ROOT, 'tools', 'run.py'), '--rom',
                        os.path.join(ROOT, 'build', 'som_test.sfc'), '--from', state,
                        '--probe', os.path.join(ROOT, 'tests', 'probe_castcount.lua')] + steps,
                       capture_output=True, text=True)
    out = r.stdout
    stats = [l for l in out.splitlines() if l.startswith('casts')]
    ok = 'saved state soak_' in out
    print(f'segment {s}: {stats[0] if stats else "no stats"}  {"saved" if ok else "NO STATE (" + out.splitlines()[0] + ")"}', flush=True)
    if not ok:
        break
    state = f'soak_{s}'
