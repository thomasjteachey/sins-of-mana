"""Zip the patches and their docs for sharing -> build/sinofmana_addons_<date>.zip.

Usage: python tools/package.py   (after tools/build.py)

Holds README.md (from README_PATCHES.md), ADDRESSES.md, TECHNICAL_NOTES.md (NOTES.md
without its personal Steam Deck section) and patches/*.ips.
"""
import datetime, os, re, sys, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build import ALL_PATCHES

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'build')
PRIVATE = ['## Steam Deck ROM']               # NOTES.md sections left out (paths on the user's Deck)


def notes():
    text = open(os.path.join(ROOT, 'NOTES.md'), encoding='utf-8').read()
    parts = re.split(r'(?m)^(?=## )', text)
    kept = [p for p in parts if not any(p.startswith(h) for h in PRIVATE)]
    out = ''.join(kept)
    assert '/home/deck' not in out and 'ssh' not in out.lower(), 'personal info left in TECHNICAL_NOTES.md'
    return out


def main():
    path = os.path.join(OUT, 'sinofmana_addons_%s.zip' % datetime.date.today().isoformat())
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(ROOT, 'README_PATCHES.md'), 'README.md')
        z.write(os.path.join(ROOT, 'ADDRESSES.md'), 'ADDRESSES.md')
        z.writestr('TECHNICAL_NOTES.md', notes())
        for p in ALL_PATCHES:
            z.write(os.path.join(OUT, p), 'patches/' + p)
    print('wrote', os.path.relpath(path, ROOT))
    return path


if __name__ == '__main__':
    main()
