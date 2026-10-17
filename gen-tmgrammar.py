#!/usr/bin/env python3
"""Generate a VS Code TextMate grammar from the tree-sitter coral grammar.

VS Code has no tree-sitter support, so highlighting there has to be a
TextMate (.tmLanguage.json) grammar. `tree-sitter` itself cannot emit one,
and hand-maintaining a second list of keywords guarantees drift.

So this reads `src/grammar.json` -- the artefact `tree-sitter generate`
produces from grammar.js -- and lifts every literal keyword, primitive type
and operator straight out of it. Add a keyword to grammar.js, re-run, and the
VS Code grammar follows.

Lexical shapes that a token-stream engine cannot express (the C-string prefix
vs. a coral string, `#[[attr]]` brackets, comment-vs-declaration context)
are kept as templates below and merged with the extracted tokens.
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent
GRAMMAR = ROOT / 'grammars' / 'coral' / 'src' / 'grammar.json'
OUT = ROOT.parent / 'coral-vscode' / 'syntaxes' / 'coral.tmLanguage.json'

# ---------------------------------------------------------------- extraction

def walk(node, visit):
    """Depth-first walk over a grammar.json rule body."""
    if isinstance(node, dict):
        for key, val in node.items():
            if key == 'type' and val == 'STRING':
                visit(node)
            else:
                walk(val, visit)
    elif isinstance(node, list):
        for item in node:
            walk(item, visit)


def literals_of(rule):
    """All STRING literals appearing anywhere in one rule body."""
    found = set()
    walk(rule.get('members', rule), lambda n: found.add(n['value']))
    return found


def literal(rule):
    """The single STRING literal of a rule, if that is all it is."""
    found = literals_of(rule)
    return found.pop() if len(found) == 1 else None


def rule_named(rules, name):
    return rules[name]['members'] if name in rules else None


# Tokens that only ever appear as `seq` scaffolding or as real operators.
# They must never leak into a keyword bucket; punctuation is handled by the
# #punctuation repository instead.
STRUCTURAL = frozenset({
    '(', ')', '[', ']', '{', '}', ',', ';', ':', '#[', '#[[', ']]',
})

# Genuine operators that also appear as seq scaffolding.
OPERATORS = frozenset({
    '=', '!', '?', '::', '->', '=>', '...', '!<',
})

# Never let operator punctuation be claimed as a keyword, however it was
# reached -- `distinct Name = Type;` would otherwise classify `=` as a
# declaration keyword.
NOT_A_KEYWORD = STRUCTURAL | OPERATORS


class Extractor:
    """Lifts literal tokens out of grammar.json and sorts them into buckets.

    The tricky part is that a literal like `;` is a `seq` delimiter in most
    rules, so a naive "all strings in this rule" sweep picks up punctuation
    everywhere. Instead each token is claimed by the first bucket that names
    it, and STRUCTURAL tokens are dropped up front.
    """

    def __init__(self, grammar):
        self.rules = grammar['rules']
        self.claimed = {}

    def _take(self, role, names):
        """Claim every literal in `names` for `role`, minus structural noise."""
        got = set()
        for name in names:
            body = self.rules.get(name)
            if not body:
                continue
            for tok in literals_of(body):
                if tok in NOT_A_KEYWORD:
                    continue
                if self.claimed.setdefault(tok, role) == role:
                    got.add(tok)
        return got

    # -- buckets ---------------------------------------------------------
    def types(self):
        body = self.rules.get('primitive_type')
        out = (literals_of(body) - NOT_A_KEYWORD) if body else set()
        for t in out:
            self.claimed.setdefault(t, 'type')
        return out

    def import_keywords(self):
        out = set()
        for name in ('import_declaration', 'mod_declaration'):
            body = self.rules.get(name)
            if not body:
                continue
            for tok in literals_of(body):
                if tok in NOT_A_KEYWORD:
                    continue
                # `pub` is visibility, not part of the import keyword itself.
                if tok == 'pub':
                    self.claimed.setdefault(tok, 'modifier')
                    continue
                if self.claimed.setdefault(tok, 'import') == 'import':
                    out.add(tok)
        return out

    def decl_keywords(self):
        out = self._take('decl', (
            'struct_declaration', 'variant_declaration', 'union_declaration',
            'enum_declaration', 'trait_declaration', 'extend_declaration',
            'typedef_declaration', 'distinct_declaration', 'flag_declaration',
        ))
        out -= self.modifiers()
        return out

    def modifiers(self):
        return self._take('modifier', (
            'field_declaration', 'method_declaration', 'function_declaration',
            'generic_function_declaration', 'constructor_declaration',
            'const_declaration', 'variable_declaration', 'var_declaration',
            'local_declaration', 'extern_declaration', 'generic_param',
        ))

    def control(self):
        return self._take('control', (
            'if_statement', 'switch_statement', 'for_statement',
            'while_statement', 'loop_statement', 'break_statement',
            'continue_statement', 'return_statement', 'defer_statement',
            'asm_statement', 'comptime_block', 'else_pattern',
        ))

    def builtins(self):
        return self._take('builtin', ('builtin_expression',))

    def values(self):
        out = set()
        for name in ('boolean_literal', 'null_literal'):
            body = self.rules.get(name)
            if body:
                out |= literals_of(body)
        out |= {'self'}
        out -= NOT_A_KEYWORD
        for t in out:
            self.claimed.setdefault(t, 'value')
        return out

    def operators(self):
        """Unclaimed literals from expression rules, plus the real operators."""
        out = set(OPERATORS)
        for name in ('binary_expression', 'comparison_expression',
                     'unary_expression', 'postfix_expression',
                     'assignment_expression', 'conditional_expression',
                     'cast_expression', 'field_expression',
                     'deref_field_expression', 'struct_field',
                     'variadic_parameter', 'generic_params'):
            body = self.rules.get(name)
            if not body:
                continue
            for tok in literals_of(body):
                if tok in STRUCTURAL:
                    continue
                out.add(tok)
        # anything already claimed as a keyword stays a keyword
        return {t for t in out
                if self.claimed.setdefault(t, 'operator') == 'operator'
                or self.claimed.get(t) is None}

    def attribute_names(self):
        """Names the README documents as attributes."""
        return sorted({
            'no_drop_all', 'no_drop', 'packed', 'reorder', 'inline', 'const',
            'threadlocal', 'noalias', 'condassign', 'hot', 'cold',
            'fallthrough', 'no_mangle', 'test', 'bench', 'cfg', 'link',
            'simd', 'extern', 'no_std', 'extend', 'no_extend', 'generate',
        })


def _symbol_refs(node, acc=None):
    if acc is None:
        acc = []
    if isinstance(node, dict):
        if node.get('type') == 'SYMBOL':
            acc.append(node)
        for v in node.values():
            _symbol_refs(v, acc)
    elif isinstance(node, list):
        for v in node:
            _symbol_refs(v, acc)
    return acc


# ------------------------------------------------------------------ emitting

def alt(words):
    """Regex alternation, longest first so `<<=` wins over `<<`."""
    ordered = sorted((w for w in words if w), key=len, reverse=True)
    return '|'.join(re_escape(w) for w in ordered)


def re_escape(s):
    import re
    return re.escape(s)


def word_pattern(words):
    return r'\b(?:%s)\b' % alt(words)


def build(x):
    types = sorted(x.types())
    # Order matters: a token belongs to the first bucket that claims it.
    imports = sorted(x.import_keywords())
    mods = sorted(x.modifiers())
    decl = sorted(x.decl_keywords())
    control = sorted(x.control())
    builtins = sorted(x.builtins())
    values = sorted(x.values())
    ops = sorted(x.operators())

    keywords = {
        'keyword.control.import.coral': word_pattern(imports),
        'storage.modifier.coral': word_pattern(mods),
        'keyword.declaration.type.coral': word_pattern(decl),
        'keyword.control.coral': word_pattern(control),
        'support.function.builtin.coral': word_pattern(builtins),
        'constant.language.coral': word_pattern(values),
        'storage.type.coral': word_pattern(types),
    }

    return {
        'scopeName': 'source.coral',
        'fileTypes': ['crl', 'coral'],
        'name': 'Coral',
        'patterns': [
            {'include': '#comments'},
            {'include': '#attributes'},
            {'include': '#compile-attrs'},
            {'include': '#strings'},
            {'include': '#c-strings'},
            {'include': '#chars'},
            {'include': '#numbers'},
            {'include': '#declarations'},
            {'include': '#keywords'},
            {'include': '#operators'},
            {'include': '#punctuation'},
        ],
        'repository': {
            'comments': {'patterns': [
                {'name': 'comment.line.double-slash.coral', 'match': '//.*$'},
                {'name': 'comment.block.coral', 'begin': '/\\*', 'end': '\\*/'},
            ]},
            'attributes': {'patterns': [{
                'name': 'meta.attribute.coral',
                'begin': '#\\[\\[',
                'beginCaptures': {'0': {
                    'name': 'punctuation.definition.annotation.coral'}},
                'end': '\\]\\]',
                'endCaptures': {'0': {
                    'name': 'punctuation.definition.annotation.coral'}},
                'patterns': [
                    {'name': 'support.type.attribute.coral',
                     'match': word_pattern(x.attribute_names())},
                    {'include': '#strings'},
                ],
            }]},
            'compile-attrs': {'patterns': [{
                'name': 'meta.attribute.compile.coral',
                'match': r'(@)([A-Za-z_][A-Za-z0-9_]*)',
                'captures': {
                    '1': {'name': 'punctuation.definition.annotation.coral'},
                    '2': {'name': 'support.function.compile-attribute.coral'},
                },
            }]},
            'strings': {'patterns': [{
                'name': 'string.quoted.double.coral',
                'begin': '"', 'end': '"',
                'patterns': [{'name': 'constant.character.escape.coral',
                              'match': r'\\.'}],
            }]},
            # C"…" is NUL-terminated with no length prefix, so it is scoped
            # apart from a coral string and its C prefix is called out.
            'c-strings': {'patterns': [{
                'name': 'string.quoted.double.coral.special.c-string',
                'begin': 'C"',
                'beginCaptures': {'0': {
                    'name': 'storage.type.coral c-string-prefix'}},
                'end': '"',
                'patterns': [{'name': 'constant.character.escape.coral',
                              'match': r'\\.'}],
            }]},
            'chars': {'patterns': [{
                'name': 'string.quoted.single.coral',
                'begin': "'", 'end': "'",
                'patterns': [{'name': 'constant.character.escape.coral',
                              'match': r'\\.'}],
            }]},
            'numbers': {'patterns': [
                {'name': 'constant.numeric.integer.hex.coral',
                 'match': r'\b0[xX][0-9a-fA-F][0-9a-fA-F_]*([uU][lL]{0,2}|[lL]{1,2}[uU]?)?\b'},
                {'name': 'constant.numeric.integer.binary.coral',
                 'match': r'\b0[bB][01][01_]*([uU][lL]{0,2}|[lL]{1,2}[uU]?)?\b'},
                {'name': 'constant.numeric.integer.octal.coral',
                 'match': r'\b0[oO][0-7][0-7_]*([uU][lL]{0,2}|[lL]{1,2}[uU]?)?\b'},
                {'name': 'constant.numeric.float.coral',
                 'match': r'\b[0-9][0-9_]*(\.[0-9_]*([eE][+-]?[0-9][0-9_]*)?|[eE][+-]?[0-9][0-9_]*)[fF]?\b'},
                {'name': 'constant.numeric.integer.coral',
                 'match': r'\b[0-9][0-9_]*([uU][lL]{0,2}|[lL]{1,2}[uU]?)?\b'},
            ]},
            'declarations': {'patterns': [
                {'match': r'^\s*(pub\s+)?(%s)\s+([A-Za-z_][A-Za-z0-9_]*)' % alt(decl),
                 'captures': {
                     '1': {'name': 'storage.modifier.coral'},
                     '2': {'name': 'keyword.declaration.type.coral'},
                     '3': {'name': 'entity.name.type.coral'}}},
                {'match': r'^\s*(mod)\s+([A-Za-z_][A-Za-z0-9_]*)',
                 'captures': {
                     '1': {'name': 'keyword.control.import.coral'},
                     '2': {'name': 'entity.name.namespace.coral'}}},
                {'match': r'^\s*(const)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(=)',
                 'captures': {
                     '1': {'name': 'storage.modifier.coral'},
                     '2': {'name': 'variable.other.constant.coral'},
                     '3': {'name': 'keyword.operator.coral'}}},
                {'match': r'^\s*(extern)\s*(\(?\s*(C|c)\s*\)?)?\s*([A-Za-z_][A-Za-z0-9_]*)',
                 'captures': {
                     '1': {'name': 'storage.modifier.coral'}}},
                {'match': r'(?<![A-Za-z0-9_])(%s)\s+([A-Za-z_][A-Za-z0-9_]*)' % alt(decl),
                 'captures': {
                     '1': {'name': 'keyword.declaration.type.coral'},
                     '2': {'name': 'entity.name.type.coral'}}},
            ]},
            'keywords': {'patterns': [
                {'name': name, 'match': pat}
                for name, pat in keywords.items() if pat != r'\b(?:)\b'
            ]},
            'operators': {'patterns': [
                {'name': 'keyword.operator.coral', 'match': alt(ops)},
            ]},
            'punctuation': {'patterns': [
                {'name': 'punctuation.definition.block.coral', 'match': '[{}]'},
                {'name': 'punctuation.definition.parameters.coral', 'match': '[()]'},
                {'name': 'punctuation.definition.subscript.coral', 'match': r'[\[\]]'},
                {'name': 'punctuation.separator.coral', 'match': r'[,;.]'},
                {'name': 'punctuation.definition.colon.coral', 'match': ':'},
                {'name': 'punctuation.definition.annotation.coral', 'match': '[@#]'},
            ]},
        },
    }


def main():
    grammar = json.loads(GRAMMAR.read_text())
    x = Extractor(grammar)
    tm = build(x)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(tm, indent=2) + '\n')
    print(f'wrote {OUT}')
    print(f'  types       {len(x.types())}: {" ".join(sorted(x.types()))}')
    print(f'  decl kw     {len(x.decl_keywords())}: {" ".join(sorted(x.decl_keywords()))}')
    print(f'  modifiers   {len(x.modifiers())}: {" ".join(sorted(x.modifiers()))}')
    print(f'  control     {len(x.control())}: {" ".join(sorted(x.control()))}')
    print(f'  builtins    {len(x.builtins())}: {" ".join(sorted(x.builtins()))}')
    print(f'  values      {len(x.values())}: {" ".join(sorted(x.values()))}')
    print(f'  operators   {len(x.operators())}: {" ".join(sorted(x.operators()))}')


if __name__ == '__main__':
    main()
