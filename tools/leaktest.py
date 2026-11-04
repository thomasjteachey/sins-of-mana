"""Leak hunt: walk into the ice cave and out again over and over, logging the resource pools.

Usage: python tools/leaktest.py START_STATE SEGMENTS CYCLES [KILL_AT [KILL_STEP]]
Starts in the save-statue room north of the ice cave (state `statue`). Each cycle: walk down into
the cave (enemies spawn and start acting), wait, walk up out of it mid-action, wait. With KILL_AT
the probe also sets every enemy's HP to 0 that many frames after they appear (shifted by
KILL_STEP each cycle), so they die at different points of their routines. Segments chain through
save states leak_<n> (Mesen's headless runs stop after ~2 minutes). Results: build/leak.txt.
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CYCLE = ['down:200', 'w80', 'up:250', 'w150']       # 680 frames
start, segs, cycles = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
kill = int(sys.argv[4]) if len(sys.argv) > 4 else None
step = int(sys.argv[5]) if len(sys.argv) > 5 else 7
state, n = start, 1
for s in range(1, segs + 1):
    cfg = ['LEAK_CYCLE = %d' % n, 'LEAK_START = 5', 'LEAK_LEN = 680']
    if kill is not None:
        cfg += ['KILL_AT = %d' % (((kill - 10 + (n - 1) * step) % 80) + 10), 'KILL_STEP = %d' % step]
    open(os.path.join(ROOT, 'build', 'probe_leak_cfg.lua'), 'w').write('\n'.join(cfg) + '\n')
    steps = ['w4'] + CYCLE * cycles + ['save:leak_%d' % s, 'shot:leak_%d' % s]
    r = subprocess.run([sys.executable, '-I', os.path.join(ROOT, 'tools', 'run.py'), '--rom',
                        os.path.join(ROOT, 'build', 'som_test.sfc'), '--from', state,
                        '--probe', os.path.join(ROOT, 'tests', 'probe_leak.lua')] + steps,
                       capture_output=True, text=True)
    ok = 'saved state leak_%d' % s in r.stdout
    print('segment %d: %s' % (s, 'ok' if ok else 'FAILED ' + (r.stdout.splitlines() or [''])[-1]), flush=True)
    if not ok:
        break
    state, n = 'leak_%d' % s, n + cycles
