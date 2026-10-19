# Coral for Zed

Tree-sitter based syntax highlighting, bracket matching, auto-indentation,
code outline, and language server integration for the
[Coral](https://github.com/coralc-lang/coralc) programming language.

The extension ships the parser and queries plus a small Rust `extension.wasm`
that starts `coralc --serve` when the compiler is on `PATH`. It does not bundle
the compiler, formatter, or debugger.

---

## Contents

| Path | Purpose |
| --- | --- |
| `extension.toml` | Extension manifest. Declares the `coral` grammar and language server. |
| `src/lib.rs` | Finds `coralc` (or the `coral-lsp` launcher) and starts it with `--serve`. |
| `tree-sitter-coral/grammar.js` | The grammar. The single source of truth for syntax. |
| `tree-sitter-coral/src/parser.c` | Generated parser (regenerate with `tree-sitter generate`). |
| `grammars/coral.wasm` | The grammar artifact Zed loads. |
| `languages/coral/config.toml` | Language metadata: suffixes, comments, brackets, tab size. |
| `languages/coral/highlights.scm` | Syntax highlighting queries. |
| `languages/coral/indents.scm` | Auto-indentation ranges. |
| `languages/coral/outline.scm` | Outline / structure queries. |
| `languages/coral/brackets.scm` | Bracket matching. |
| `languages/coral/textobjects.scm` | Vim-mode `af` / `if` / `ac` / `ic` text objects. |
| `build.sh` | Builds the grammar and extension wasm, then installs locally. |
| `test/` | Snippet corpus and hand-written examples used to validate the grammar. |

---

## Building and installing

The grammar build needs `tree-sitter`, `clang` with the `wasm32` target, and
`wasm-ld` (from `lld`). The extension needs Rust with the
`wasm32-wasip2` target:

```sh
rustup target add wasm32-wasip2
./build.sh                      # build + install to the default location
./build.sh /some/other/dir      # build + install elsewhere
```

Most users should install Coral with the project installer instead; it places
the compiler and the extension together:

```sh
curl -fsSL https://raw.githubusercontent.com/coralc-lang/coralc/main/install.sh | sh
```

Zed loads extensions from `~/.local/share/zed/extensions/installed/`. An
extension only loads if it is also present in that directory's `index.json`, so
`build.sh` installs the tree and refreshes the manifest entry.

---

## The grammar

The grammar is written from `coral-docs/grammar.md`. Notable decisions, in the
order they matter when reading `grammar.js`:

### Declarations are type-first

There is no `fn` keyword. A function is just a type followed by a name:

```coral
u32 add(u32 a, u32 b) { return a + b; }
```

Because the type comes first, every declaration that can hold a declarator
shares one hidden prefix rule, `_typed_decl_head`:

```
_typed_decl_head = <type> <name> [ <declarator> ]
```

`field_declaration`, `local_declaration`, `method_declaration`, and
`function_declaration` are all that shared head plus a distinguishing suffix
(`;`, `= expr;`, `(…)`). This keeps the type/name/init/params decision to a
single LR choice instead of exploding into conflicts.

### Modifiers

| Modifier | Meaning |
| --- | --- |
| `pub` | Visibility. The *only* visibility keyword — there is no `export`. |
| `static` | No implicit receiver. |
| `extern("C")` / `extern[c]` | Foreign ABI. Both spellings parse. |
| `volatile` | Volatile access qualifier. |
| `comptime` | Compile-time. |

### Type syntax

Types are prefix-annotated and postfix-decorated, and the two compose:

| Form | Example | Node |
| --- | --- | --- |
| Prefix `const` | `const u8*` | `const_type` |
| Prefix `comptime` | `comptime T` | `comptime_type` |
| Dyn trait | `any Comparable` | `any_type` |
| Pointer | `u8*`, `u8**` | `pointer_type` |
| Array | `u8[64]`, `u8[4][4]` | `array_type` |
| Slice | `u8[]` | `slice_type` |
| Generic | `Option<u8>`, `HashMap<K, V>` | `generic_type` |
| Qualified | `mod::sub::Name` | `qualified_type` |
| Tuple | `(u8, u32)`, `struct(u32, u32)` | `tuple_type` |
| Fn pointer | `void(u64)`, `bool(T, T)` | `function_type` |
| Flag | `flag(arch) { … }` | `flag_type` |

The declared name of a function *pointer* parameter comes from the enclosing
parameter, not from the type:

```coral
usize(K) hashFn      // parameter( function_type(usize, (K)), hashFn )
const T* constData(const self*)   // self is valid in type position
```

### `char` is not `cchar`

`char` is the builtin 32-bit UTF-32 scalar and is a `primitive_type`.

`cchar` is **not** a keyword or primitive. It is a `distinct` supplied by the
standard library:

```coral
pub distinct cchar = flag (arch) { x86_64 => { i8 }, else => { u8 } };
```

It therefore parses as an ordinary `named_type`, exactly like any user type.
Adding `cchar` to the primitive list would break every file that declares it.

### `C"…"` strings

`C"…"` is a C string: NUL-terminated, no length prefix. It is a separate node
from a coral string so it can be coloured differently:

```scheme
(string_literal) @string
(c_string)       @string.special
```

Changing the colour of C strings is a one-line edit in `highlights.scm`. The
node itself is a single lexer token, so the leading `C` cannot currently be
coloured independently of the string body without splitting the token in
`grammar.js`.

### Aggregate declarations

```coral
pub struct Point<T> { f32 x; f32 y; }              // fields + methods
variant Option<T> { None, Some { T value; } }      // tagged variant (sum type)
union Word { u64 bits; bool flag; }                 // untagged union
enum Color { Red, Green, Blue = 5 }                // plain enum
trait Comparable { bool less(T other); }            // method list, no bodies
pub extend<T> Option<T> { T unwrap() { … } }        // inherent methods
extend Shape : Comparable { u32 area() const; }    // trait conformance
```

Methods take no explicit receiver; `self` is implicit. `static` methods and
`static Name new(…)` constructors take no receiver at all.

### Statements

```coral
u8 tmp[72];                 // declaration, no initialiser
u64 total = 0;              // declaration with initialiser
var inferred = total + 1;   // var exists only to drive inference
for (usize i = 0; i < n; i++) doThing(i);
for (u32 j : range) { … }
for (const u8 [ k, v ] : pairs) { … }   // destructuring range form
if (x) a() else b();
switch (v) {                        // pattern cases, `=>`, comma-separated
    Color::Red => { … },
    Some { value } => { … },
    3 => { … },
    _ => { … },
    else => { … },                  // catch-all; also spelled #[[fallthrough]]
}
comptime { … }                      // compile-time block that emits code
defer release();
asm "nop" { out }
```

`if`, `else`, `switch`, and a bare block are all expressions, so they may
appear on the right of an assignment.

---

## Attributes

Attributes are the only annotation channel, spelled `#[[…]]`, and are chained
with commas:

```coral
#[[reorder, packed]]
struct Both { u8 a; u32 b; }
```

The compiler does not yet honour all of these; the mark is documented so the
editor can highlight them now.

### Storage and codegen

| Attribute | Effect |
| --- | --- |
| `#[[no_drop_all]]` | Turn off auto-RAII for the whole translation unit. |
| `#[[no_drop]]` | Turn off auto-RAII for one variable or scoped block. |
| `#[[packed]]` | Packed struct — no padding. |
| `#[[reorder]]` | Reorder fields for the most efficient layout. |
| `#[[inline]]` | Hint that the function should be inlined. |
| `#[[hot]]` | Hot path hint for the optimiser. |
| `#[[cold]]` | Cold path hint for the optimiser. |
| `#[[threadlocal]]` | Storage class is thread-local. |
| `#[[noalias]]` | The pointer argument is known not to alias. |
| `#[[no_mangle]]` | Keep the symbol name unmangled. |
| `#[[simd]]` | Allow SIMD lowering. |
| `#[[cfg]]` | Conditional-compilation guard. |
| `#[[link]]` | Linkage directive. |
| `#[[test]]` | Test function. |
| `#[[bench]]` | Benchmark function. |
| `#[[extern]]` | Extern-shaped declaration. |
| `#[[no_std]]` | Do not implicitly import the standard library. |

### Semantics

| Attribute | Effect |
| --- | --- |
| `#[[const]]` | Const method/function. May not mutate `self` or params. Also spelled as a trailing `const` after the parameter list. |
| `#[[condassign]]` | Allow `=` at the top level of the next `if`/`while`/`for`/`switch` condition. |
| `#[[fallthrough]]` | Let a `switch` case fall into the next one instead of requiring an `else` arm. |

### Extending declarations

| Attribute | Effect |
| --- | --- |
| `#[[extend]]` | Extend the item with the following declarations. |
| `#[[no_extend]]` | Forbid extending the item; `extend` blocks for it are rejected. |

Both attach to `struct`, `variant`, `union`, `enum`, `trait`, and `distinct`
declarations, before the keyword:

```coral
#[[no_extend]]
pub struct Vec2 { f32 x; f32 y; }
```

### Code generation

| Attribute | Effect |
| --- | --- |
| `#[[generate(Drop, Eq)]]` | Trait boilerplate generator. Takes a parenthesised, comma-separated list of trait names — analogous to Rust's `derive`. |

`pub` is **not** an attribute. It is the visibility keyword itself and is
rejected in `#[[…]]`.

---

## Editor ↔ compiler communication

The extension contributes the language server itself in `extension.toml`:

```toml
[language_servers.coral]
name = "Coral Language Server"
languages = ["Coral"]
```

`src/lib.rs` implements `language_server_command`. It first asks
`worktree.which("coralc")` and runs `coralc --serve`; if that is absent it falls
back to `coral-lsp`, the launcher installed by `build.sh`, which also searches
`$CORALC`, `$CORAL_HOME/coralc`, and the platform install roots. If neither is
present the language server stays off, but highlighting still works.

The extension sandbox cannot probe arbitrary filesystem paths, so discovery is
limited to binaries on `PATH`. No user settings are required. To pin a specific
compiler, use Zed's standard language server override:

```json
{
  "language_servers": {
    "coral": { "command": { "path": "/path/to/coralc", "args": ["--serve"] } }
  }
}
```

`coralc --serve` speaks LSP over stdio. [`PROTOCOL.md`](./PROTOCOL.md) is the
contract: JSON-RPC 2.0, one object per line, with `publishDiagnostics`,
`documentSymbol`, `hover`, `definition`, `references`, `completion`, and two
Coral-specific methods (`coral/attributes`, `coral/typeInfo`).

### Where the launcher looks for the compiler

First hit wins:

1. `$CORALC`
2. `$CORAL_HOME/coralc`
3. `coralc` on `PATH`
4. platform roots — `~/.coral/bin`, `~/.local/bin`, `~/bin`,
   `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`; on Windows
   `%LOCALAPPDATA%\coral`, `%LOCALAPPDATA%\Programs\coral`

`CORAL_HOME` matches the `env = { CORAL_HOME = … }` block in the build
manifests, and `/usr/local/bin` matches `artifact "coralc" { install = … }`.

The editor never passes library paths or `CORAL_HOME` to the compiler. On Linux
the compiler's libraries live under `~/.coral` (`lib`, `store`, `projects`, and
the per-project `cache`, `modules.map`, `artifacts`, `graph.dot`,
`metrics.json`), and that stays the compiler's business — hard-coding it in an
editor would break the moment the layout changes.

---

## Language server

See [LANGUAGE-SERVER.md](./LANGUAGE-SERVER.md) for status, design, and what
the compiler must implement.

## Known gaps

The grammar is not complete. The corpus in `test/` is the regression suite;
`snippets/` are single-feature files and `corpus/` is a mixed file.

The parser handles: declarations and the shared `_typed_decl_head` prefix,
`C"…"` strings, string-path `import`/`mod`, `flag` types, `comptime {}` blocks,
`any Trait`, `self` in type position, `if`/`switch`/blocks as expressions,
chained `#[[…]]` attributes, and C-style and range-based `for`.

It does **not** yet handle, all of which appear in real Coral code:

- `Tuple-typed` struct-literal shorthand in every position
- Some deeply nested generic arguments inside struct-literal field initialisers
- `switch` patterns with `|` alternatives (the decided `Or` form)
- Trait-satisfaction lists beyond a single `: Trait` clause

`./build.sh` regenerates, compiles, and installs in one step, so the loop for
closing these is: edit `grammar.js`, run `build.sh`, re-parse a failing file.

---

## Licence

MIT
