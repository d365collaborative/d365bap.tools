# ps1-lint (vendored)

PowerShell lint hook scripts for `prek.toml`. They started as a copy of the
PS1 hooks from an internal-only module and are maintained in this repo from
here on — no submodule, no sync back. Rule changes happen here via normal PRs.

What runs on `**.ps1`:
- `psscriptanalyzer/Run.ps1` — native PSScriptAnalyzer (Error + Warning,
  fails on Error) plus repo rules: `PSOnlyCommentBasedHelp`,
  `PSUseCmdletStructure`, `PSHelpSynopsis/Description/Parameter/Notes/Example`,
  `PSAvoidCommandAliases` / `PSAvoidParameterAliases` (opt out per directory
  with a `ps1-lint.json` file, see the internal `Get-Ps1AliasConfiguration.ps1`).
- `ps1-format/Run.ps1` — Invoke-Formatter with `internal/Ps1FormatSettings.psd1`
  plus UTF-8 BOM enforcement. Rewrites files and exits 1 when anything changed.
- `setup/Run.ps1` — installs PSScriptAnalyzer (CurrentUser) when missing.
