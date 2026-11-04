# Module layout

PSFramework module layout.

- Public commands: `functions/` ([AGENTS.md](functions/AGENTS.md))
- Internal helpers: `internal/functions/`
- Export list: `FunctionsToExport` in `d365bap.tools.psd1`
- Tests / XML / docs agents: see those folders' `AGENTS.md` or `readme.md`

Paths are case-sensitive on Linux/macOS. Prefer `Resolve-PSFPath` / `Import-ModuleFile` for portable paths.
