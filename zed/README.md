# Coral language server launcher (Zed fallback)

The Zed extension starts `coralc --serve` directly through
`worktree.which("coralc")`. No `settings.json` entry is needed.

`coral-lsp.sh` is the fallback for environments where `coralc` is not on
`PATH`. It searches, in order:

1. `$CORALC`
2. `$CORAL_HOME/coralc`
3. `coralc` on `PATH`
4. platform install roots (`~/.coral/bin`, `~/.local/bin`, `~/bin`,
   `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`, and the Windows
   `%LOCALAPPDATA%` locations)

Then it execs the compiler with `--serve`. `install.sh` installs it to
`~/.local/bin/coral-lsp`; normal users do not need it because the compiler
installer puts `coralc` on `PATH`.

If no compiler is found the launcher exits 126 with a message, and Zed simply
runs no Coral server. Highlighting is unaffected.
