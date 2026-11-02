function Test-Ps1SelectObjectCalculatedProperty {
	param($Node)

	if ($Node -is [Management.Automation.Language.ArrayLiteralAst]) {
		foreach ($itemElement in $Node.Elements) {
			if ($itemElement -is [Management.Automation.Language.HashtableAst]) { $true; return }
		}
	}

	$Node -is [Management.Automation.Language.HashtableAst]
}

function New-Ps1SelectObjectPropertyDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseExplicitSelectObjectProperty'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1SelectObjectPropertyDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] -and $Node.GetCommandName() -eq 'Select-Object' }, $true)) {
		$tmpElements = @($itemCommand.CommandElements)
		if ($tmpElements.Count -le 1) { continue }

		$tmpHasProperty = @($tmpElements | Where-Object {
				$_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -like 'Prop*'
			}).Count -gt 0

		if ($tmpHasProperty) { continue }

		$tmpHasCalculatedProperty = @($tmpElements[1..($tmpElements.Count - 1)] | Where-Object {
				Test-Ps1SelectObjectCalculatedProperty -Node $_
			}).Count -gt 0

		if (-not $tmpHasCalculatedProperty) { continue }

		New-Ps1SelectObjectPropertyDiagnostic -Path $Path `
			-Extent $itemCommand.Extent `
			-Message 'Use -Property with Select-Object when the property list contains a calculated property. Name the parameter so the projection is explicit.'
	}
}
