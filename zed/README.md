# Coral language server (Zed hook)
#
# coralc does not speak LSP yet. The wiring below is the editor half of
# PROTOCOL.md and goes live the moment the compiler grows a `serve` mode; no
# change here is needed then.
#
# Zed starts a language server named `coral` for the "Coral" language when it
# is listed in `language_servers`. `command` is resolved on PATH by Zed; this
# block points it at the same candidates the VS Code extension probes, in the
# same order, but through a tiny launcher so the fallbacks are honoured.
#
# Add this to ~/.config/zed/settings.json under "language_servers":

{
  "Coral": {
    "language_servers": ["coral", "..."]
  },
  "language_servers": {
    "coral": {
      "source": "custom",
      "command": {
        "path": "coral-lsp",
        "args": [],
        "env": {}
      }
    }
  }
}

# The `...` in the first list keeps every other language's servers; drop it if
# Coral should have none.
#
# `coral-lsp` is a small launcher (see coral-lsp.sh) that locates coralc using
# the resolution order in PROTOCOL.md. You can also bypass it and give Zed an
# absolute path if you know where coralc lives:
#
#   "path": "/home/you/.coral/bin/coralc"
#
# If no compiler is found the launcher exits non-zero and Zed simply runs no
# Coral server — highlighting is unaffected because it needs no compiler.
