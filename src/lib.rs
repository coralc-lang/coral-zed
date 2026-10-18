use zed_extension_api as zed;

/// Coral extension.
///
/// Beyond the grammar, this contributes the Coral language server itself, so
/// `coralc --serve` is discovered and started automatically. Declaring it here
/// rather than in each user's settings.json is the whole point: a contributor
/// in `~/.config/zed/settings.json` fixes exactly one machine and does not
/// ship, whereas `language_server_command` is part of the published extension.
struct CoralExtension;

impl zed::Extension for CoralExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command, String> {
        // Prefer the compiler directly. `coralc --serve` speaks LSP over stdio,
        // so there is nothing for the extension to add -- and skipping the
        // launcher means users do not have to install one.
        //
        // `worktree.which` is the only filesystem access available here: the
        // extension sandbox does not support `std::fs`, so paths cannot be
        // probed for existence. If neither binary is on PATH we return an
        // error, which leaves tree-sitter highlighting working untouched.
        if let Some(coralc) = worktree.which("coralc") {
            return Ok(zed::Command {
                command: coralc,
                args: vec!["--serve".to_string()],
                env: Default::default(),
            });
        }

        // Fallback: the launcher script, which searches $CORALC and
        // $CORAL_HOME/coralc as well as PATH and platform install roots.
        if let Some(launcher) = worktree.which("coral-lsp") {
            return Ok(zed::Command {
                command: launcher,
                args: vec![],
                env: Default::default(),
            });
        }

        Err("coralc not found on PATH; install the Coral compiler to enable \
             language server features"
            .to_string())
    }

    /// Nothing to send yet. `coralc` takes no initialization options, but Zed
    /// asks for this on every start, so returning `None` is the explicit way
    /// to say "no options" rather than leaving it unimplemented.
    fn language_server_initialization_options(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        _worktree: &zed::Worktree,
    ) -> Result<Option<serde_json::Value>, String> {
        Ok(None)
    }
}

zed::register_extension!(CoralExtension);