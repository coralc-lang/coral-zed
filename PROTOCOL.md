# Coral editor protocol

The contract between an editor and `coralc --serve`.

**Status: this document is normative.** Both extensions are implemented and
tested against it. `coralc --serve` is a work in progress; where it diverges,
the divergence is listed explicitly under [Current state](#current-state) so
the gap is visible rather than assumed.

---

## 1. Transport

**JSON-RPC 2.0 over stdio, with LSP base-protocol framing.**

Every message, in both directions, is preceded by a header block and then
exactly *N* bytes of UTF-8 JSON:

```
Content-Length: 143\r\n
Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n
\r\n
{"jsonrpc":"2.0","id":1,"result":{…}}
```

Rules:

- `Content-Length` is **bytes**, not characters. A UTF-8 multibyte character
  counts as its encoded length.
- The header block ends with a **blank line** (`\r\n\r\n`). The server may omit
  `Content-Type`; clients must accept its absence.
- Messages are not newline-delimited. A `\n` inside a JSON string is escaped as
  `\n` and does not terminate a message.
- **No JSON-RPC batching.** LSP does not support it; clients and servers must
  not send arrays.
- **Stdout carries the protocol and nothing else.** No banners, no progress, no
  debug prints. Anything human-facing goes to **stderr**.

> **Correction.** Earlier revisions of this document specified one JSON object
> per line. That was wrong: the real `coralc --serve` already emits
> `Content-Length` framing. Both clients were fixed to match.

### Startup

```
editor → coralc --serve        (newline-framed argv; the flag, not a subcommand)
coralc → stdio                 (nothing may be written before initialize is answered)
```

---

## 2. Lifecycle

```
editor → {"jsonrpc":"2.0","id":1,"method":"initialize","params":{…}}
coralc → {"jsonrpc":"2.0","id":1,"result":{"capabilities":{…},"serverInfo":{…}}}
editor → {"jsonrpc":"2.0","method":"initialized","params":{}}
editor → {"jsonrpc":"2.0","method":"textDocument/didOpen","params":{…}}
coralc → {"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{…}}
        …
editor → {"jsonrpc":"2.0","id":2,"method":"shutdown","params":null}
coralc → {"jsonrpc":"2.0","id":2,"result":null}
editor → {"jsonrpc":"2.0","method":"exit","params":null}
coralc → process exits
```

Hard requirements, per LSP 3.18:

- `initialize` **must** carry `protocolVersion`, `processId`, `rootUri`, and
  `capabilities`.
- Before responding to `initialize`, the server must not send any request or
  notification — with one exception: `window/showMessage`,
  `window/logMessage`, `window/showMessageRequest`, `telemetry/event`, and
  `$/progress` are permitted while `initialize` is in flight.
- A request received before `initialize` must be answered with error
  **`-32002` (ServerNotInitialized)**. Notifications received before it are
  dropped, except `exit`.
- `initialize` may be sent **only once**.
- The client must not send anything else until it has received the
  `InitializeResult`.
- `shutdown` is a **request**; `exit` is a **notification**.
- Exit code **0** if `shutdown` was received, **1** otherwise. On stdin EOF the
  server should exit cleanly.

### `initialize` — client → server

```jsonc
{
  "protocolVersion": "3.18",
  "processId": 4711,
  "rootUri": "file:///home/you/coralc",
  "workspaceFolders": null,
  "clientInfo": {"name": "coral-vscode"},
  "capabilities": {
    "textDocument": {
      "hover": {"contentFormat": ["markdown"]},
      "documentSymbol": {"hierarchicalDocumentSymbolSupport": false}
    }
  }
}
```

### `initialize` — server → client

```jsonc
{
  "capabilities": {
    "textDocumentSync": 1,
    "hoverProvider": true
  },
  "serverInfo": {"name": "coralc", "version": "0.1.0"}
}
```

`textDocumentSync: 1` means **Full**. Both extensions send full text and
neither implements incremental sync.

---

## 3. Locating the compiler

Resolution order, first hit wins. Both extensions implement this identically.

1. **Explicit setting** — `coral.languageServer.path` (VS Code) or
   `language_servers.coral.path` (Zed). Absolute or `~`-prefixed.
2. **`CORALC`** environment variable.
3. **`CORAL_HOME`** → `$CORAL_HOME/coralc[.exe]`.
4. **`coralc` on `PATH`**.
5. **Platform install roots:**

   | Platform | Paths |
   | --- | --- |
   | Linux | `~/.coral/bin/coralc`, `~/.local/bin/coralc`, `~/bin/coralc`, `/usr/local/bin/coralc`, `/usr/bin/coralc` |
   | macOS | `~/.coral/bin/coralc`, `~/bin/coralc`, `/opt/homebrew/bin/coralc`, `/usr/local/bin/coralc` |
   | Windows | `%USERPROFILE%\.coral\bin\coralc.exe`, `%LOCALAPPDATA%\coral\coralc.exe`, `%LOCALAPPDATA%\Programs\coral\coralc.exe` |

6. **Give up.** Log `no coralc found`; run no server. Highlighting is
   tree-sitter/TextMate only and keeps working.

A configured path that does not exist falls through to the next candidate rather
than failing outright. A candidate that exists but fails to spawn is a real
error and should be surfaced.

The launcher must invoke `coralc --serve`, never `coralc serve`.

### How each editor starts it

| Editor | Mechanism |
| --- | --- |
| VS Code | The extension spawns the binary itself on activation, probing for `coralc`. No configuration. |
| Zed | The extension's `language_server_command` resolves `coralc` via `worktree.which()` and passes `--serve`. No configuration. |

Neither editor asks the user to configure anything. A `settings.json`
contributor would fix one machine and would not ship.

### Library resolution is the compiler's problem

The editor never passes library paths, module maps, or `CORAL_HOME`. On Linux
the compiler owns `~/.coral/{lib,store,projects}` and the per-project
`.coral/{cache,modules.map,artifacts,graph.dot,metrics.json}`. Encoding any of
that in an editor breaks the moment the compiler changes its layout.

---

## 4. Document synchronisation

Full text, no incremental ranges. Coral files are small and the compiler parses
whole files anyway.

```jsonc
// textDocument/didOpen
{"textDocument":{"uri":"file:///p/x.crl","languageId":"coral","version":1,"text":"…"}}

// textDocument/didChange — one full-content change
{"textDocument":{"uri":"file:///p/x.crl","version":2},"contentChanges":[{"text":"…"}]}

// textDocument/didClose
{"textDocument":{"uri":"file:///p/x.crl"}}
```

`version` is monotonic per document. The editor may coalesce rapid edits and
send the latest text when the server goes quiet.

On `didClose` the server should clear that document's diagnostics.

---

## 5. Methods

Every method is optional. An absent capability means the editor hides the
affordance; it never surfaces an error.

| Method | Direction | Phase | Purpose |
| --- | --- | --- | --- |
| `initialize` / `initialized` | both | required | Handshake |
| `shutdown` / `exit` | both | required | Teardown |
| `textDocument/didOpen` / `didChange` / `didClose` | editor → server | required | Sync |
| `textDocument/publishDiagnostics` | server → editor | required | Errors |
| `textDocument/hover` | editor → server | target | Type under cursor |
| `textDocument/documentSymbol` | editor → server | target | Outline |
| `textDocument/definition` | editor → server | target | Go to declaration |
| `textDocument/references` | editor → server | target | Find uses |
| `textDocument/completion` | editor → server | target | Completions |
| `coral/attributes` | editor → server | target | Attributes inside `#[[…]]` |
| `coral/typeInfo` | editor → server | target | Node inspector |

`$/cancelRequest` and `$/progress` are optional server→client/client→server
extras; neither extension depends on them.

---

## 6. `textDocument/publishDiagnostics` (server → editor)

```jsonc
{
  "method": "textDocument/publishDiagnostics",
  "params": {
    "uri": "file:///p/x.crl",
    "version": 2,
    "diagnostics": [
      {
        "range": {"start": {"line": 0, "character": 21},
                  "end":   {"line": 0, "character": 24}},
        "severity": 1,
        "code": "P0001",
        "source": "coral",
        "message": "expected '{', found 'u32'"
      }
    ]
  }
}
```

Rules:

- `severity` is LSP: **1** error, **2** warning, **3** information, **4** hint.
- `code` is the compiler's **stable error-code identifier** (`P0001`, `P0002`,
  `P0003`, …) so editors can key off identity rather than message text.
- `source` is `"coral"`.
- Lines and characters are **zero-based UTF-16 code units**, not bytes.
- The server must publish a **full set per document after every change**,
  including an **empty array** when a document becomes clean — an empty array
  is what clears the file in the editor. Silence is not "no errors".
- Parse failures are diagnostics too. They must not abort the rest of the file;
  recover and keep going so one syntax error does not cascade.

---

## 7. `textDocument/hover` (editor → server)

Request:

```jsonc
{"method":"textDocument/hover",
 "params":{"textDocument":{"uri":"file:///p/x.crl"},
           "position":{"line":4,"character":6}}}
```

Response — `Hover | null`:

```jsonc
{
  "contents": {"kind": "markdown", "value": "```coral\nT at(usize i)\n```\n\nArray element access."},
  "range": {"start": {"line": 4, "character": 5}, "end": {"line": 4, "character": 7}}
}
```

`null` is a valid answer meaning "nothing to say here". It must **not** be an
error, and the editor must not surface one.

---

## 8. `textDocument/documentSymbol` (editor → server)

Returns `DocumentSymbol[] | SymbolInformation[] | null`. The editor advertises
`hierarchicalDocumentSymbolSupport: false`, so `SymbolInformation[]` is the
expected shape.

```jsonc
[{"name": "at", "kind": 12,
  "detail": "T at(usize i)",
  "location": {"uri": "file:///p/x.crl",
               "range": {"start": {"line": 4, "character": 5},
                         "end":   {"line": 4, "character": 7}}}}]
```

| Coral | `SymbolKind` |
| --- | --- |
| `struct`, `union`, `extend`, `variant`, `enum` | 5 Class |
| `trait` | 11 Interface |
| functions, methods, constructors | 12 Function |
| fields, variant members | 8 Field |
| constants, locals | 13 Variable |

`detail` is the declaration as written **minus its body**. Because Coral is
type-first this is what makes an outline readable: `T at(usize i)`, not `at`.

---

## 9. Coral-specific methods

`coral/attributes` — every attribute understood at a position, so the editor
can complete inside `#[[…]]`:

```jsonc
{"result": [
  {"name": "no_drop_all", "doc": "disable auto-RAII for this file"},
  {"name": "packed",      "doc": "packed struct layout"},
  {"name": "generate",    "doc": "generate trait boilerplate",
                          "parameters": [{"name": "traits", "variadic": true}]}
]}
```

`coral/typeInfo` — the node under the cursor for the scopes/inspect
affordances:

```jsonc
{"result": {
  "kind": "method", "name": "at", "qualified": "Arr.at",
  "type": "fn(usize) -> T", "doc": "Array element access.", "attributes": []}}
```

---

## 10. Errors

| Code | Meaning | When |
| --- | --- | --- |
| `-32700` | ParseError | Malformed JSON on the wire |
| `-32600` | InvalidRequest | Valid JSON, invalid JSON-RPC shape |
| `-32601` | **MethodNotFound** | Unsupported method — **the normal "not implemented" answer** |
| `-32602` | InvalidParams | Bad params for a known method |
| `-32603` | InternalError | Server bug |
| `-32002` | ServerNotInitialized | Request before `initialize` |
| `-32800` | RequestCancelled | `$/cancelRequest` was honoured |

`-32601` is the single most important one: a server that does not implement a
method **must** answer with it rather than ignoring the request or crashing.
Both extensions treat `-32601` as "feature absent" and silently degrade.

---

## 11. What the editor never asks for

- **Semantic tokens.** Highlighting belongs to tree-sitter/TextMate. A second
  highlighter would only drift.
- **Formatting.** Coral has no formatter.
- **Incremental parse state, module graphs, build orchestration.** Compiler
  internals.

---

## 12. Current state

Verified against `~/.coral/bin/coralc 0.1.0` (`coralc --help` advertises
`--serve  run the language server on stdio (LSP)`), including the coral-vscode
live handshake (`tools/test-live-server.js`, 9/9) and the compiler-side suite
(lifecycle, exit codes, UTF-16 columns, project report, cleared markers).

**Working:**

- `Content-Length` framing, exactly as specified above.
- `initialize` → `{textDocumentSync: 1, hoverProvider: true}`; a request
  before `initialize` answers **`-32002`**; a second `initialize` answers
  `-32600`.
- Malformed JSON answers **`-32700`**; non-object messages `-32600`.
- `shutdown` / `exit` with the specified exit codes: **0** after `shutdown`,
  **1** without; stdin EOF exits cleanly.
- `textDocument/didOpen` / `didChange` / `didClose` (full text); `didClose`
  publishes an empty set, clearing the document's markers.
- `textDocument/publishDiagnostics` with `source: "coral"`, stable `P####` /
  `T####` codes, UTF-16 `character` offsets, and an **empty array** whenever a
  document becomes clean — silence is not "no errors".
- **Whole-project error report**: opening any file analyzes the build entry
  (`coral.crlb`) and publishes diagnostics for every file in the import
  closure, so errors in files the open buffer never imports appear too. Files
  that stop having records are cleared on the next report.
- `textDocument/hover` returns the markdown-typed declaration of the
  expression or symbol under the cursor (locals and top-level names).
- `-32601` for unimplemented methods; `$/cancelRequest` accepted.

**Gaps to close:**

| Gap | Detail |
| --- | --- |
| No `documentSymbol` | `-32601`. Outline is empty. |
| No `definition` / `references` | `-32601`. |
| No `completion` | `-32601`. |
| No `coral/attributes` / `coral/typeInfo` | `-32601`. |

Hover does not send the optional `range` field yet. Type spellings come from
the compiler's own type printer, so diagnostics and hover follow real
semantics rather than a parallel grammar — there is no separate parser to
drift.