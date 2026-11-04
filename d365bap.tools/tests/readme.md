# Tests

- `general/` — module health and style
- `functions/` — generated signature snapshots (do not hand-edit; see [AGENTS.md](functions/AGENTS.md))
- `behavior/` — offline user-visible behavior (`build/Test-Behavior.ps1`)

PR gates: [GATES.md](../../GATES.md). Runner regressions: `build/Test-PSScriptAnalyzerConsolidation.ps1`, `build/Test-PesterRunners.ps1`.
