# Format XML

Do not edit consolidated `d365bap.tools.*.Format.ps1xml`. Maintain per-type views under `formats/table/` and `formats/list/` (see those AGENTS.md files). Push only per-type files.

Local preview only (never commit):
`pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1`
