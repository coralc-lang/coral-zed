# Coral editor protocol

How an editor talks to `coralc` when it is running as a language server.

The compiler does not implement this yet. This document is the contract both
extensions are built against, so the editor side is finished and the compiler
only has to be written once.

## Transport

- **JSON-RPC 2.0** over **stdio**.
- One JSON object per line, UTF-8, `\n`-terminated. No embedded newlines.
- Content-Length framing is **not** used. Stdout is reserved entirely for the
  protocol; the compiler must not print banners or progress to it. Anything
  human-facing goes to stderr.

### Lifecycle

```
editor → {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"rootUri":"file:///…"}}
coralc → {"jsonrpc":"2.0","id":1,"result":{"capabilities":{…},"serverInfo":{…}}}
editor → {"jsonrpc":"2.0","method":"initialized","params":{}}
editor → {"jsonrpc":"2.0","method":"textDocument/didOpen","params":{…}}
coralc → {"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{…}}
…
editor → {"jsonrpc":"2.0","id":2,"method":"shutdown","params":null}
coralc → {"jsonrpc":"2.0","id":2,"result":null}
editor → {"jsonrpc":"2.0","method":"exit","params":null}
```

`exit` must terminate the process. On EOF the editor closes stdin and the
compiler should exit cleanly.

## Locating the compiler

Resolution order, first hit wins. Both extensions implement this identically.

1. **Explicit setting** — `coral.languageServer.path` (VS Code) or
   `language_servers.coral.path` (Zed). An absolute or `~`-prefixed path to the
   executable.
2. **`CORALC`** environment variable — same meaning as (1).
3. **`CORAL_HOME`** environment variable → `$CORAL_HOME/coralc[.exe]`.
   This is what a build using `env = { CORAL_HOME = … }` sets.
4. **`coralc` on `PATH`** — covers `/usr/local/bin`, Homebrew, `winget`, Nix
   profiles, and anything else on the search path.
5. **Platform install roots**, in order:

   | Platform | Paths |
   | --- | --- |
   | Linux | `~/.coral/bin/coralc`, `~/.local/bin/coralc`, `/usr/local/bin/coralc`, `/usr/bin/coralc` |
   | macOS | `~/.coral/bin/coralc`, `~/bin/coralc`, `/opt/homebrew/bin/coralc`, `/usr/local/bin/coralc` |
   | Windows | `%USERPROFILE%\.coral\bin\coralc.exe`, `%LOCALAPPDATA%\coral\coralc.exe`, `%LOCALAPPDATA%\Programs\coral\coralc.exe` |

6. **Give up**, and log that no compiler was found. Highlighting keeps working —
   it needs no compiler.

The editor never guesses a compiler it cannot execute. If a candidate exists
but fails to spawn, that is an error worth surfacing; if a candidate is absent,
resolution simply continues.

### Library resolution is the compiler's job

The editor does **not** pass library paths, module maps, or `CORAL_HOME`. The
compiler resolves its own libraries: on Linux they live under `~/.coral`
(`~/.coral/lib`, `~/.coral/store`, `~/.coral/projects`, and the per-project
`.coral/cache`, `.coral/modules.map`, `.coral/artifacts`, `.coral/graph.dot`,
`.coral/metrics.json`). Editors have no business knowing any of that, and
hard-coding it would break the moment the compiler changes its layout.

## Document synchronisation

Full text sync only — no incremental ranges. Coral files are small and the
compiler parses whole files anyway.

```jsonc
// textDocument/didOpen
{"textDocument":{"uri":"file:///p/x.crl","languageId":"coral","version":1,"text":"…"}}

// textDocument/didChange — full content each time
{"textDocument":{"uri":"file:///p/x.crl","version":2},"contentChanges":[{"text":"…"}]}
```

`version` is monotonic per document. The editor may coalesce rapid edits: send
the latest text when the compiler goes quiet rather than on every keystroke.

## Capabilities

The editor probes for these. Every one is optional — an absent capability means
the editor degrades to plain text, never to an error.

### `textDocument/publishDiagnostics` (server → editor)

```jsonc
{
  "method": "textDocument/publishDiagnostics",
  "params": {
    "uri": "file:///p/x.crl",
    "diagnostics": [
      {
        "range": {
          "start": { "line": 12, "character": 4 },
          "end":   { "line": 12, "character": 17 }
        },
        "severity": 1,
        "code": "ParseExpectedDecl",
        "source": "coralc",
        "message": "expected declaration"
      }
    ]
  }
}
```

Lines and characters are UTF-16 code units, zero-based — LSP convention.

`severity` is LSP: `1` error, `2` warning, `3` info, `4` hint.

`code` is the compiler's `ErrorCode` enum name, so editors can key off stable
identifiers rather than message text.

An empty `diagnostics` array clears the file. The compiler should re-publish a
full set rather than deltas, and should publish for every open document after
each parse, including when the result is clean.

### `textDocument/documentSymbol` (editor → server)

Fills the outline panel. Returns `SymbolInformation[]`:

```jsonc
[{
  "name": "Option",
  "kind": 11,                 // 5=Class 11=Struct 12=Function 13=Variable
  "range": { … },             // whole declaration
  "selectionRange": { … },    // the name only
  "detail": "variant Option<T>",
  "children": [
    { "name": "Some", "kind": 22, … }
  ]
}]
```

Mapping: `struct`/`union`/`extend` → Class(5); `variant`/`enum` → Class(5);
`trait` → Interface(11); functions and methods → Function(12); fields,
constants, and `variant` members → Field(8)/Variable(13).

`detail` is the declaration as written, minus the body — that is what makes the
outline readable for Coral's type-first syntax (`u32 at(usize i)`).

### `textDocument/hover` (editor → server)

Returns `Hover` with Markdown, for the type of the symbol under the cursor:

```jsonc
{"contents": {"kind":"markdown","value":"```coral\nu32\n```\n\nfield of `Arr<u8, 4>`"}}
```

### `textDocument/definition`, `textDocument/references`

Standard LSP shapes. `definition` returns `Location | Location[] | null`;
`references` takes a `context.includeDeclaration` flag and returns `Location[]`.

### `textDocument/completion`

Standard `CompletionItem[]`. Useful because `Option<T>` / `Result<T, E>` are
variants whose members are reached through the `::` path, which is tedious to
type by hand.

### `coral/attributes` (editor → server)

Coral-specific. Returns every attribute understood at a position, so the
editor can offer completions inside `#[[…]]`:

```jsonc
// → {"result": [
//   {"name":"no_drop_all","doc":"disable auto-RAII for this file"},
//   {"name":"packed",      "doc":"packed struct layout"},
//   {"name":"generate",    "doc":"generate trait boilerplate",
//                          "parameters":[{"name":"traits","variadic":true}]}
// ]}
```

### `coral/typeInfo` (editor → server)

The node under the cursor, for the scopes/inspect affordances:

```jsonc
{"result": {
  "kind": "function",              // field | method | type | function | variant …
  "name": "unwrap",
  "qualifiedName": "std::data::option::Option::unwrap",
  "type": "T",
  "attributes": ["const", "inline"],
  "doc": "Returns the wrapped value; asserts on None."
}}
```

## Errors

Use JSON-RPC error objects for transport failures, and LSP `ResponseError`
shapes (`{ code, message, data }`) for request failures:

```jsonc
{"jsonrpc":"2.0","id":7,"error":{"code":-32601,"message":"method not found: coral/attributes"}}
```

`-32601` for an unimplemented method is the expected response before the
compiler grows that feature. Editors must treat it as "not supported" and hide
the affordance, not as a failure.

## What the editor never asks for

- Semantic tokens. Highlighting is tree-sitter's job on the editor side, and
  duplicating it would mean two highlighters drifting apart.
- Formatting. Coral has no formatter.
- Incremental parsing state, module graphs, or build orchestration. Those stay
  inside the compiler.
