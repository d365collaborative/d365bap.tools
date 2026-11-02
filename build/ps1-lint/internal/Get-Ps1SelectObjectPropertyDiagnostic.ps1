function Test-Ps1SelectObjectCalculatedProperty {
	param($Node)

	if ($Node -is [Management.Automation.Language.ArrayLiteralAst]) {
		foreach ($itemElement in $Node.Elements) {
			if ($itemElement -is [Management.Automation.Language.HashtableAst]) { $true; return }
		}
	}

	$Node -is [Management.Automation.Language.HashtableAst]
}

function Get-Ps1SelectObjectPropertyDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$colCommands = @(Get-Ps1AstNode $Analysis CommandAst | Where-Object { $_.GetCommandName() -eq 'Select-Object' })
	foreach ($itemCommand in $colCommands) {
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

		New-Ps1Diagnostic $Path 'PSUseExplicitSelectObjectProperty' 'Use -Property with Select-Object when the property list contains a calculated property. Name the parameter so the projection is explicit.' $itemCommand.Extent
	}
}
