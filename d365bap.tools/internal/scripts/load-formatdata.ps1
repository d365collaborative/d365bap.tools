# FormatsToProcess cannot be used: each entry is a nested module load (limit 10),
# and RequiredModules (Az.Accounts) already consumes that budget, so views never
# register. Listed in ScriptsToProcess so this file runs as a real script
# ($PSScriptRoot is set). Do not load it via postimport/Import-ModuleFile —
# that uses InvokeScript, $PSScriptRoot is empty, and Join-Path fails.
#
# Table first so it is the default view; List second so Format-List still works.
if ($PSScriptRoot) {
	$moduleRoot = Split-Path (Split-Path $PSScriptRoot)
}
elseif ($script:ModuleRoot) {
	$moduleRoot = $script:ModuleRoot
}
else {
	return
}

foreach ($name in @(
		'd365bap.tools.Table.Format.ps1xml'
		, 'd365bap.tools.List.Format.ps1xml'
	)) {
	$formatFile = Join-Path $moduleRoot "xml\$name"
	if (Test-Path -LiteralPath $formatFile) {
		Update-FormatData -AppendPath $formatFile
	}
}
