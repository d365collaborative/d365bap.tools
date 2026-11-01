function New-Ps1OneParameterPerLineDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseOneParameterPerLine'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1OneParameterPerLineDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$isModuleFile = $normalized -match '/d365bap\.tools/(functions|internal)/'
	$isLintTooling = $normalized -match '/build/ps1-lint/'
	if (-not $isModuleFile -and -not $isLintTooling) { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$tmpLines = @{}
		foreach ($itemElement in $itemCommand.CommandElements) {
			if ($itemElement -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			$line = $itemElement.Extent.StartLineNumber
			if (-not $tmpLines.ContainsKey($line)) { $tmpLines[$line] = 0 }
			$tmpLines[$line]++
		}

		$hasCrowdedLine = @($tmpLines.Keys | Where-Object { $tmpLines[$_] -gt 1 }).Count -gt 0
		if (-not $hasCrowdedLine) { continue }

		New-Ps1OneParameterPerLineDiagnostic -Path $Path `
			-Extent $itemCommand.Extent `
			-Message 'A command with more than one parameter puts each parameter on its own line. The first parameter may stay on the command line; every later parameter gets a new line.'
	}
}
