[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '../d365bap.tools/xml'
$colFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1xml')
$colFailures = [System.Collections.Generic.List[string]]::new()

foreach ($itemFile in $colFiles) {
	try {
		$null = [xml] (Get-Content -LiteralPath $itemFile.FullName -Raw)
	}
	catch {
		$colFailures.Add("$($itemFile.FullName): $($_.Exception.Message)") | Out-Null
	}
}

if ($colFailures.Count -gt 0) {
	foreach ($itemFailure in $colFailures) { Write-Error $itemFailure }
	exit 1
}

Write-Host "Validated $($colFiles.Count) format XML files."
