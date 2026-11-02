function Get-Ps1MultilineSelectObjectPropertyDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$message = 'Put each Select-Object calculated property on its own line. More than one property on one line is hard to read.'

	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if (($commandName -split '\\')[-1] -ine 'Select-Object') { continue }

		$tmpElements = @($itemCommand.CommandElements)
		$tmpArgument = $null
		for ($index = 1; $index -lt $tmpElements.Count; $index++) {
			$itemElement = $tmpElements[$index]
			if ($itemElement -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if ($itemElement.ParameterName -ine 'Property') { continue }

			if ($null -ne $itemElement.Argument) {
				$tmpArgument = $itemElement.Argument
			}
			elseif (($index + 1) -lt $tmpElements.Count) {
				$tmpArgument = $tmpElements[$index + 1]
			}
			break
		}
		if ($null -eq $tmpArgument) { continue }

		$tmpProperty = if ($tmpArgument -is [Management.Automation.Language.ArrayLiteralAst]) {
			@($tmpArgument.Elements)
		}
		else {
			@($tmpArgument)
		}
		if ($tmpProperty.Count -le 1) { continue }

		$tmpPreviousLine = $tmpProperty[0].Extent.StartLineNumber
		for ($index = 1; $index -lt $tmpProperty.Count; $index++) {
			$itemProperty = $tmpProperty[$index]
			if ($itemProperty -is [Management.Automation.Language.HashtableAst] -and
				$itemProperty.Extent.StartLineNumber -eq $tmpPreviousLine) {
				New-Ps1Diagnostic $Path 'PSUseMultilineSelectObjectProperty' $message $itemProperty.Extent
				break
			}

			$tmpPreviousLine = $itemProperty.Extent.StartLineNumber
		}
	}
}
