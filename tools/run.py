"""Run the built ROM headless in Mesen with a list of scripted inputs.

Usage:
  python tools/run.py [--rom build/som_desc.sfc] [--from STATE] STEP [STEP ...]

Steps:
  start / a / b / x / y / l / r / select / up / down / left / right   press for 2 frames, then wait 20
  a*5            repeat 5 times
  y+b            press together
  a:10           hold 10 frames
  w60            wait 60 frames
  shot:NAME      screenshot -> build/shots/NAME.png
  save:NAME      save state -> build/states/NAME.mss
  dump:NAME      all 128 KB of work RAM -> build/ram/NAME.bin
  poke:7FEE61=02,03   write bytes to work RAM (e.g. give Duran test weapons)
Options:
  --probe tests/probe_x.lua   extra Lua callbacks (logging) loaded into the run
"""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, 'build')
MESEN = os.path.join(ROOT, 'third_party', 'mesen2', 'Mesen.exe')


def to_lua(args):
    out = []
    for a in args:
        if a.startswith('w') and a[1:].isdigit():
            out.append('{wait=%d}' % int(a[1:]))
        elif a.startswith('shot:'):
            out.append('{shot="%s"}' % a[5:])
        elif a.startswith('save:'):
            out.append('{save="%s"}' % a[5:])
        elif a.startswith('dump:'):
            out.append('{dump="%s"}' % a[5:])
        elif a.startswith('poke:'):
            out.append('{poke="%s"}' % a[5:])
        else:
            reps = 1
            if '*' in a:
                a, r = a.split('*'); reps = int(r)
            hold = 2
            if ':' in a:
                a, h = a.split(':'); hold = int(h)
            out += ['{keys="%s", hold=%d, wait=20}' % (a, hold)] * reps
    return 'STEPS = {\n  ' + ',\n  '.join(out) + '\n}\n'


def main():
    args = sys.argv[1:]
    rom = os.path.join(BUILD, 'som_desc.sfc')
    start = None
    if '--rom' in args:
        i = args.index('--rom'); rom = os.path.abspath(args[i + 1]); del args[i:i + 2]
    if '--from' in args:
        i = args.index('--from'); start = args[i + 1]; del args[i:i + 2]
    probe = None
    if '--probe' in args:
        i = args.index('--probe'); probe = os.path.abspath(args[i + 1]).replace('\\', '/'); del args[i:i + 2]
    os.makedirs(os.path.join(BUILD, 'shots'), exist_ok=True)
    os.makedirs(os.path.join(BUILD, 'states'), exist_ok=True)
    os.makedirs(os.path.join(BUILD, 'ram'), exist_ok=True)
    with open(os.path.join(BUILD, 'steps.lua'), 'w') as f:
        f.write(to_lua(args))
        f.write('START_STATE = %s\n' % ('"%s"' % start if start else 'nil'))
        f.write('DEBUG_PAD = %s\n' % ('true' if os.environ.get('DEBUG_PAD') else 'false'))
        f.write('PROBE_FILE = %s\n' % ('"%s"' % probe if probe else 'nil'))
    log = os.path.join(BUILD, 'lua_log.txt')
    if os.path.exists(log):
        os.remove(log)
    try:
        r = subprocess.run([MESEN, '--testRunner', rom, os.path.join(ROOT, 'tests', 'drive.lua')],
                           capture_output=True, text=True, timeout=300)
        code = r.returncode
    except subprocess.TimeoutExpired:
        code = 'timeout'
    print('mesen exit:', code)
    if os.path.exists(log):
        print(open(log).read().rstrip())


if __name__ == '__main__':
    main()
