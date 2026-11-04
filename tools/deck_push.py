"""Build the Deck ROM and install it on the Steam Deck.

Usage: python tools/deck_push.py [--no-build] [--force]

  1. python tools/build.py and tools/deckrom.py (skip with --no-build)
  2. refuses while RetroArch runs on the Deck
  3. copies every RetroArch state of the game saved since the installed ROM was put
     there and runs tools/statecheck.py on it; a state whose CPU (or interrupted main
     code) is in mod code (banks $40, $52-$58, $CB) stops the install unless --force,
     since loading it with a rebuilt ROM can crash
  4. backs up the installed ROM to previous-roms/<name>.<md5[:8]>.sfc (once per build)
  5. uploads to <name>.new, checks its MD5, then moves it into place

Needs `ssh deck` to work without a password (key ~/.ssh/deck_claude, see NOTES.md).
"""
import hashlib, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = os.path.join(ROOT, 'build', 'deck', 'Sins of ManaNORMAL Plus.sfc')
HACKS = '/home/deck/Emulation/roms/snes/Hacks'
REMOTE = HACKS + '/Sins of ManaNORMAL Plus.sfc'
BACKUP = '/home/deck/Emulation/saves/sinofmana-backup-2026-11-02/previous-roms'
STATES = '/run/media/deck/1fb496c3-9151-4748-b052-7abce079d3d4/steamapps/common/RetroArch/states'
STATE_GLOB = 'Sins of ManaNORMAL Plus.state*'
MOD_BANKS = ('40', '52', '53', '54', '55', '56', '57', '58', 'CB')
SSH = ['ssh', '-o', 'ConnectTimeout=15', '-o', 'BatchMode=yes', 'deck']


def ssh(cmd, data=None, check=True):
    r = subprocess.run(SSH + [cmd], input=data, capture_output=True, timeout=300)
    if check and r.returncode != 0:
        sys.exit('deck: %s failed: %s' % (cmd[:60], r.stderr.decode(errors='replace').strip()))
    return r.stdout.decode(errors='replace')


def main():
    args = sys.argv[1:]
    if '--no-build' not in args:
        for tool in ('build.py', 'deckrom.py'):
            r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', tool)], cwd=ROOT,
                               capture_output=True, text=True)
            print(r.stdout.strip().splitlines()[-1] if r.stdout.strip() else '')
            if r.returncode != 0:
                sys.exit('%s failed:\n%s%s' % (tool, r.stdout, r.stderr))
    data = open(LOCAL, 'rb').read()
    md5 = hashlib.md5(data).hexdigest()
    print('new ROM', md5)

    if ssh('pgrep -i -x retroarch >/dev/null && echo RUNNING || echo ok').strip() != 'ok':
        sys.exit('RetroArch is running on the Deck: close it first')
    old = ssh("md5sum '%s' | cut -d' ' -f1" % REMOTE).strip()
    print('installed', old)
    if old == md5:
        print('already installed')
        return

    # states saved since the installed ROM went in
    names = ssh("cd '%s' && find . -maxdepth 1 -name '%s' -newer '%s' -printf '%%f\\n'"
                % (STATES, STATE_GLOB, REMOTE)).split()
    risky = []
    with tempfile.TemporaryDirectory() as tmp:
        for n in names:
            p = os.path.join(tmp, n)
            open(p, 'wb').write(subprocess.run(SSH + ["cat '%s/%s'" % (STATES, n)], capture_output=True,
                                               timeout=120).stdout)
            out = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'statecheck.py'), p],
                                 capture_output=True, text=True).stdout.strip()
            print('state', out)
            banks = re.findall(r'(?:PC=|interrupted )([0-9A-F]{2}):', out)
            if any(b in MOD_BANKS for b in banks):
                risky.append(n)
    if not names:
        print('no states saved since the installed ROM')
    if risky and '--force' not in args:
        sys.exit('these states were saved inside mod code and may crash with the new ROM: %s '
                 '(re-run with --force to install anyway)' % ', '.join(risky))

    bak = "%s/Sins of ManaNORMAL Plus.%s.sfc" % (BACKUP, old[:8])
    ssh("mkdir -p '%s' && ([ -f '%s' ] || cp -p '%s' '%s')" % (BACKUP, bak, REMOTE, bak))
    print('backed up', os.path.basename(bak))
    tmpname = HACKS + '/Sins_of_ManaNORMAL_Plus.new'
    ssh("cat > '%s'" % tmpname, data=data)
    got = ssh("md5sum < '%s' | cut -d' ' -f1" % tmpname).strip()
    if got != md5:
        ssh("rm -f '%s'" % tmpname, check=False)
        sys.exit('upload corrupted (%s), nothing installed' % got)
    ssh("mv -f '%s' '%s'" % (tmpname, REMOTE))
    print('installed', ssh("md5sum '%s' | cut -d' ' -f1" % REMOTE).strip())


if __name__ == '__main__':
    main()
