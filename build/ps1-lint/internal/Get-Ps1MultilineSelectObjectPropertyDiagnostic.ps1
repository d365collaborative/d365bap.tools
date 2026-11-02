function New-Ps1MultilineSelectObjectPropertyDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseMultilineSelectObjectProperty'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1MultilineSelectObjectPropertyDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$message = 'Put each Select-Object calculated property on its own line. More than one @{ Name = ...; Expression = ... } element on one line is hard to read.'

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if (($commandName -split '\\')[-1] -ine 'Select-Object') { continue }

		$tmpElements = @($itemCommand.CommandElements)
		$hasProperty = @($tmpElements | Where-Object {
				$_ -is [Management.Automation.Language.CommandParameterAst] -and $_.ParameterName -ieq 'Property'
			}).Count -gt 0
		if (-not $hasProperty) { continue }

		$tmpPreviousLine = $tmpElements[0].Extent.StartLineNumber
		$tmpCalculated = @()
		$tmpMisplaced = @()

		for ($index = 1; $index -lt $tmpElements.Count; $index++) {
			$itemElement = $tmpElements[$index]

			if ($itemElement -is [Management.Automation.Language.CommandParameterAst]) {
				$tmpPreviousLine = $itemElement.Extent.StartLineNumber
				continue
			}

			$tmpChild = if ($itemElement -is [Management.Automation.Language.ArrayLiteralAst]) {
				@($itemElement.Elements)
			}
			else {
				@($itemElement)
			}
			foreach ($itemChild in $tmpChild) {
				if ($itemChild -is [Management.Automation.Language.HashtableAst]) {
					$tmpCalculated += $itemChild
					if ($itemChild.Extent.StartLineNumber -eq $tmpPreviousLine) { $tmpMisplaced += $itemChild }
				}

				$tmpPreviousLine = $itemChild.Extent.StartLineNumber
			}
		}

		if ($tmpCalculated.Count -gt 1 -and $tmpMisplaced.Count -gt 0) {
			New-Ps1MultilineSelectObjectPropertyDiagnostic -Path $Path `
				-Extent $tmpMisplaced[0].Extent `
				-Message $message
		}
	}
}
