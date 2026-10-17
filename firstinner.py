#!/usr/bin/env python3
"""Find the innermost ERROR node in a .crl parse and show its source context.

An outer ERROR often spans a whole file. The node nested deepest inside it is
the actual problem, so that is what we locate.

   python3 firstinner.py <file.crl> [--lines 10]
"""
import re, subprocess, sys, pathlib

GRAMMAR = pathlib.Path('/home/cerie/Documents/coral-zed/grammars/coral')
ROOT = pathlib.Path('/home/cerie/Documents/coralc')
NODE = re.compile(r'\((ERROR|MISSING)[^\[]*?\[(\d+), (\d+)\] - \[(\d+), (\d+)\]')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    lines = 10
    if '--lines' in sys.argv:
        lines = int(sys.argv[sys.argv.index('--lines') + 1])
    path = pathlib.Path(args[0])
    if not path.is_absolute():
        path = ROOT / path
    r = subprocess.run(['tree-sitter', 'parse', str(path)], cwd=GRAMMAR,
                       capture_output=True, text=True)
    out = r.stdout
    nodes = [(int(a), int(b), int(c), int(d))
             for _k, a, b, c, d in NODE.findall(out)]
    if not nodes:
        print('clean')
        return

    # keep only nodes containing no other node
    inner = []
    for i, (r0, c0, r1, c1) in enumerate(nodes):
        has = False
        for j, (s0, t0, s1, t1) in enumerate(nodes):
            if i == j:
                continue
            if (s0 > r0 or (s0 == r0 and t0 >= c0)) and \
               (s1 < r1 or (s1 == r1 and t1 <= c1)):
                has = True
                break
        if not has:
            inner.append((r0, c0, r1, c1))

    src = path.read_text(errors='replace').split('\n')
    print(f'{len(nodes)} error nodes, {len(inner)} innermost')
    for (r0, c0, r1, c1) in inner[:6]:
        print(f'\n--- {path.name}:{r0 + 1}:{c0 + 1}')
        for i in range(max(0, r0 - 2), min(len(src), r0 + lines)):
            mark = '>>' if i == r0 else '  '
            print(f'{mark} {i + 1:5d} | {src[i]}')


if __name__ == '__main__':
    main()
