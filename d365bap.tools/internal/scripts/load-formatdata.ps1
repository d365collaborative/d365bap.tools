# FormatsToProcess cannot be used: each entry is a nested module load (limit 10),
# and RequiredModules (Az.Accounts) already consumes that budget, so views never
# register. This script is listed in ScriptsToProcess (caller scope, no nesting)
# and also run from postimport when loading individual files from git.
#
# Table first so it is the default view; List second so Format-List still works.
$moduleRoot = Split-Path (Split-Path $PSScriptRoot)
foreach ($name in @(
		'd365bap.tools.Table.Format.ps1xml'
		, 'd365bap.tools.List.Format.ps1xml'
	)) {
	$formatFile = Join-Path $moduleRoot "xml\$name"
	if (Test-Path -LiteralPath $formatFile) {
		Update-FormatData -AppendPath $formatFile
	}
}
