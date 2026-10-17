#!/usr/bin/env python3
"""Show the first parse error in one .crl file with source context.

   python3 firsterror.py lib/std/x86_64/linux/parser/csv.crl [--lines 12]
"""
import re, subprocess, sys, pathlib

GRAMMAR = pathlib.Path('/home/cerie/Documents/coral-zed/grammars/coral')
ROOT = pathlib.Path('/home/cerie/Documents/coralc')
NODE = re.compile(r'\((ERROR|MISSING)([^\n]*)')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    lines = 12
    if '--lines' in sys.argv:
        lines = int(sys.argv[sys.argv.index('--lines') + 1])
    path = pathlib.Path(args[0])
    if not path.is_absolute():
        path = ROOT / path
    r = subprocess.run(['tree-sitter', 'parse', str(path)], cwd=GRAMMAR,
                       capture_output=True, text=True)
    src = path.read_text(errors='replace').split('\n')
    out = r.stdout
    m = re.search(r'\((ERROR|MISSING)[^\[]*?\[(\d+), (\d+)\] - \[(\d+), (\d+)\]', out)
    if not m:
        print('clean')
        return
    kind, r0, c0, r1, c1 = m.group(1), *map(int, m.groups()[1:])
    print(f'{kind} at {path.name}:{r0 + 1}:{c0 + 1}  '
          f'-> :{r1 + 1}:{c1 + 1}')
    print()
    lo = max(0, r0 - 3)
    hi = min(len(src), r1 + 1 + lines)
    for i in range(lo, hi):
        mark = '>>' if i == r0 else '  '
        caret = ''
        if i == r0:
            caret = '  ' + ' ' * c0 + '^' * max(1, c1 - c0)
        print(f'{mark} {i + 1:5d} | {src[i]}{caret}')


if __name__ == '__main__':
    main()
