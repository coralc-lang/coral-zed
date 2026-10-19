#!/usr/bin/env python3
"""Parse every coral .crl file and report the root causes of failures.

Two numbers matter:

  clean files / total files    the headline number
  innermost ERROR buckets      what to fix next, most frequent first

Only *innermost* error nodes are bucketed. An ERROR that wraps a whole file is
a symptom; the small node inside it is the cause, so counting the outer ones
just tells you which files are broken rather than why.
"""
import argparse, collections, concurrent.futures as cf, os, pathlib, re, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path(os.environ.get('CORAL_REPO', HERE.parent / 'coral'))
GRAMMAR = HERE / 'tree-sitter-coral'
NODE = re.compile(r'\((ERROR|MISSING)[^\[]*?\[(\d+), (\d+)\] - \[(\d+), (\d+)\]')

# Directories that hold Coral source. `lib` is the standard library and
# `wallvm` the bytecode toolchain; both are real-world Coral.
ROOTS = ('lib', 'wallvm', 'compiler', 'bootstrap')


def corpus():
    out = []
    for rel in ROOTS:
        d = ROOT / rel
        if d.is_dir():
            out += sorted(d.rglob('*.crl'))
    seen, uniq = set(), []
    for f in out:
        if f not in seen:
            seen.add(f)
            uniq.append(f)
    return uniq


def parse_one(path):
    r = subprocess.run(['tree-sitter', 'parse', str(path)], cwd=GRAMMAR,
                       capture_output=True, text=True)
    return path, r.stdout


def innermost(nodes):
    """Drop nodes that strictly contain another node."""
    spans = [(int(a), int(b), int(c), int(d)) for _k, a, b, c, d in nodes]
    keep = []
    for i, (r0, c0, r1, c1) in enumerate(spans):
        has_inner = False
        for j, (s0, t0, s1, t1) in enumerate(spans):
            if i == j:
                continue
            if (s0 > r0 or (s0 == r0 and t0 >= c0)) and \
               (s1 < r1 or (s1 == r1 and t1 <= c1)):
                has_inner = True
                break
        if not has_inner:
            keep.append((r0, c0, r1, c1))
    return keep


def snippet(src, r0, c0, r1):
    line = src[r0] if r0 < len(src) else ''
    if r0 == r1 or len(line) - c0 < 6:
        return line[c0:c0 + 58].strip()
    return line[c0:].strip()[:58]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-n', '--top', type=int, default=25)
    ap.add_argument('-j', '--jobs', type=int, default=12)
    ap.add_argument('-f', '--files', action='store_true',
                    help='list every failing file with its first error')
    args = ap.parse_args()

    files = corpus()
    results = {}
    with cf.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        for path, out in ex.map(parse_one, files):
            results[path] = out

    buckets = collections.Counter()
    samples = collections.defaultdict(list)
    failing = []

    for path, out in results.items():
        nodes = NODE.findall(out)
        if not nodes:
            continue
        src = path.read_text(errors='replace').split('\n')
        spans = innermost(nodes)
        first = None
        for (r0, c0, r1, c1) in sorted(spans):
            text = snippet(src, r0, c0, r1)
            if not text:
                continue
            key = re.sub(r'"[^"]*"', '"…"', text)
            key = re.sub(r'\s+', ' ', key)
            buckets[key] += 1
            if len(samples[key]) < 3:
                samples[key].append(f'{path.relative_to(ROOT)}:{r0 + 1}')
            if first is None:
                first = (r0 + 1, text)
        failing.append((len(spans), str(path.relative_to(ROOT)), first))

    total = len(files)
    clean = total - len(failing)
    errs = sum(f[0] for f in failing)
    print(f'files        {total}')
    print(f'clean        {clean}  ({100 * clean // max(1, total)}%)')
    print(f'failing      {len(failing)}')
    print(f'innermost error nodes  {errs}')
    print()
    print(f'=== top {args.top} root causes')
    for k, v in buckets.most_common(args.top):
        print(f'{v:5d}  {k}')
        for s in samples[k][:2]:
            print(f'          {s}')
    if args.files:
        print(f'\n=== failing files')
        for n, f, first in sorted(failing, reverse=True):
            loc = f'{first[0]}: {first[1]!r}' if first else '?'
            print(f'{n:5d}  {f}  {loc}')


if __name__ == '__main__':
    main()
