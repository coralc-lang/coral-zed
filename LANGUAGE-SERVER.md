# Editor ↔ compiler language server

Status, design, and what the compiler has to implement.

`coralc` does not speak LSP yet. Everything described here on the editor side
is finished, tested, and shipped; it sits dormant until the compiler grows a
`serve` mode. No editor change is needed when that lands.

---

## What exists now

| Piece | Location | State |
| --- | --- | --- |
| Protocol spec | `PROTOCOL.md` (both repos) | Final |
| VS Code client | `coral-vscode/extension.js` | Done, 7 transport tests |
| Zed launcher | `coral-zed/zed/coral-lsp.sh` | Done, installed to `~/.local/bin/coral-lsp` |
| Compiler lookup | both | Done, 6 resolution tests |
| Style check | `coral-vscode/tools/fake-coralc.js` | Stand-in server for testing |
| Build gating | `coral-zed/build.sh` | Fails the build if any of it regresses |

Neither editor needs a compiler to highlight Coral. Highlighting is
tree-sitter/TextMate only, so a missing compiler costs you diagnostics,
navigation, and completion — not colour.

---

## Transport

JSON-RPC 2.0 over stdio, one UTF-8 JSON object per line, `\n`-terminated.

No `Content-Length` framing. Stdout carries the protocol and nothing else, so
the compiler must not print banners or progress there; stderr is for humans.

```
editor → {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"rootUri":"file:///…"}}
coralc → {"jsonrpc":"2.0","id":1,"result":{"capabilities":{…},"serverInfo":{…}}}
editor → {"jsonrpc":"2.0","method":"initialized","params":{}}
…
editor → {"jsonrpc":"2.0","id":2,"method":"shutdown","params":null}
coralc → {"jsonrpc":"2.0","id":2,"result":null}
editor → {"jsonrpc":"2.0","method":"exit","params":null}
```

Full-text document sync only, no incremental ranges — Coral files are small and
the compiler parses whole files anyway. `version` is monotonic per document and
the editor coalesces rapid edits.

---

## Compiler location

Both editors resolve identically, first hit wins:

1. **Explicit setting** — `coral.languageServer.path` (VS Code),
   `language_servers.coral.path` (Zed)
2. **`$CORALC`** — direct override
3. **`$CORAL_HOME/coralc`** — matches the `env = { CORAL_HOME = … }` block in
   the build manifests
4. **`coralc` on `PATH`**
5. **Platform install roots**

| Platform | Candidates |
| --- | --- |
| Linux | `~/.coral/bin`, `~/.local/bin`, `~/bin`, `/usr/local/bin`, `/usr/bin` |
| macOS | `~/.coral/bin`, `~/bin`, `/opt/homebrew/bin`, `/usr/local/bin` |
| Windows | `%LOCALAPPDATA%\coral`, `%LOCALAPPDATA%\Programs\coral` (`coralc.exe`) |

`/usr/local/bin` is not arbitrary — it matches
`artifact "coralc" { install = "/usr/local/bin"; }` in `build_sys.md`.

A configured path that does not exist falls through to the next candidate rather
than failing outright. If nothing is found, the editor says so once and runs no
server.

### Libraries are the compiler's problem

The editor never passes library paths, module maps, or `CORAL_HOME` to the
compiler. On Linux the compiler's libraries live under `~/.coral`:

```
~/.coral/
  coralc            the binary
  lib/              std + platform sources
  store/            content-addressed store (v1/objects/<hh>/<hash>.crlo)
  projects/         per-project build state
  cache/            per-project, derived: v1/<module>/meta, *.fp
  modules.map       resolved module graph
  artifacts/        build outputs
  graph.dot         dependency graph
  metrics.json      build metrics
```

`store/`, `cache/`, `modules.map`, `artifacts/`, `graph.dot`, and
`metrics.json` are all compiler-internal. Encoding any of that in an editor
would break the moment the layout changes, so both clients deliberately know
none of it beyond "coralc exists somewhere".

---

## Capabilities

Every method is optional. An absent one — or a `-32601` response — means the
editor hides that affordance, never errors.

| Method | Direction | Purpose |
| --- | --- | --- |
| `textDocument/publishDiagnostics` | server → editor | Errors, warnings, parse failures |
| `textDocument/documentSymbol` | editor → server | Outline panel |
| `textDocument/hover` | editor → server | Type of the symbol under the cursor |
| `textDocument/definition` | editor → server | Go to declaration |
| `textDocument/references` | editor → server | Find all uses |
| `textDocument/completion` | editor → server | Completions |
| `coral/attributes` | editor → server | Attribute completions inside `#[[…]]` |
| `coral/typeInfo` | editor → server | Node detail for the inspector |

### Diagnostics

Standard LSP shapes. `code` is the compiler's `ErrorCode` enum name so editors
can key off stable identifiers instead of matching message text.

```jsonc
{"uri": "file:///p/x.crl", "diagnostics": [{
  "range": {"start": {"line": 12, "character": 4},
            "end":   {"line": 12, "character": 17}},
  "severity": 1,
  "code": "ParseExpectedDecl",
  "source": "coralc",
  "message": "expected declaration"
}]}
```

`severity` is LSP: 1 error, 2 warning, 3 info, 4 hint. Lines and characters are
zero-based UTF-16 code units. The compiler should publish a **full set** per
open document after each parse, including when it is clean, and an empty array
clears the file.

### Outline

`SymbolInformation[]`, hierarchical. `SymbolKind` mapping:

| Coral | Kind |
| --- | --- |
| `struct`, `union`, `extend` | Class (5) |
| `variant`, `enum` | Class (5) |
| `trait` | Interface (11) |
| functions, methods, constructors | Function (12) |
| fields, constants, variant members | Field (8) / Variable (13) |

`detail` is the declaration as written minus its body. Because Coral is
type-first, this is what makes the outline readable: `u32 at(usize i)` rather
than a bare `at`.

### Coral-specific methods

`coral/attributes` returns every attribute understood at a position, so the
editor can complete inside `#[[…]]`:

```jsonc
{"result": [
  {"name": "no_drop_all", "doc": "disable auto-RAII for this file"},
  {"name": "packed",      "doc": "packed struct layout"},
  {"name": "generate",    "doc": "generate trait boilerplate",
                          "parameters": [{"name": "traits", "variadic": true}]}
]}
```

`coral/typeInfo` returns the node under the cursor — kind, qualified name, type,
attributes, doc — for the scopes/inspect affordances.

---

## What the editor never asks for

- **Semantic tokens.** Highlighting is the editor's job via tree-sitter, and a
  second highlighter would just be something to drift.
- **Formatting.** Coral has no formatter.
- **Incremental parse state, module graphs, build orchestration.** Those stay
  inside the compiler.

---

## Wiring it up

### VS Code

No configuration needed — the extension activates on `.crl` and probes for the
compiler itself. It shows `$(search) coralc not found` in the status bar when
there is none, and *Coral: Set Up Language Server* jumps to the path setting.
*Coral: Restart Language Server* relaunches it.

### Zed

The launcher is installed to `~/.local/bin/coral-lsp`. Add to
`~/.config/zed/settings.json`:

```json
"Coral": { "language_servers": ["coral", "..."] },
"language_servers": {
  "coral": {
    "source": "custom",
    "command": { "path": "coral-lsp", "args": [] }
  }
}
```

The `"..."` keeps every other language's servers; drop it if Coral should have
none. You can bypass the launcher with an absolute path if you know where
coralc is.

Until `serve` exists the launcher exits **126** with a reason on stderr, and
Zed runs no Coral server. Highlighting is unaffected.

### Why not a `[language_servers.coral]` entry in `extension.toml`?

Zed implements `language_server_command` in a compiled `extension.wasm`, which
requires the wasi-sdk — a ~100 MB download at extension build time. The whole
extension is deliberately build-free: the grammar is compiled locally to wasm
and shipped prebuilt. The settings route keeps that property, so both editors
install with no network access at all.

When the compiler side exists, switching to the manifest form is a small change
and does not affect the protocol.

---

## Testing

```sh
node tools/test-client.js          # 7 checks — JSON-RPC, diagnostics, -32601
node tools/test-find-compiler.js   # 6 checks — resolution order
node tools/fake-coralc.js          # stand-in server, run coral-lsp against it
```

`build.sh` gates on all of them, plus the language-server launcher and a
TextMate style check, so a regression cannot ship.

To exercise the whole path without the compiler:

```sh
CORALC=/home/you/Documents/coral-vscode/tools/fake-coralc.js coral-lsp
```

---

## What the compiler needs to do

1. Accept `coralc serve` and speak JSON-RPC 2.0 on stdio, one object per line.
2. Handle `initialize`, `initialized`, `shutdown`, `exit`.
3. Handle `textDocument/didOpen` / `didChange` / `didClose` with full text.
4. Publish `textDocument/publishDiagnostics` after each parse.
5. Answer whatever of `documentSymbol`, `hover`, `definition`, `references`,
   `completion`, `coral/attributes`, `coral/typeInfo` it can, and reply
   `-32601` to the rest.
6. Keep stdout clean.

The one decision worth confirming: **the subcommand is assumed to be
`serve`**. If you would rather have a flag or a different verb, it is one line
in `coral-lsp.sh` and one in `extension.js` — say which and I will change both.
