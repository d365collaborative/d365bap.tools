function Test-Ps1OutNullShadowed {
	param($Analysis)

	foreach ($itemFunction in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		if ($itemFunction.Name -eq 'Out-Null') {
			$true
			return
		}
	}

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if (($commandName -split '\\')[-1] -ine 'Set-Alias') { continue }
		foreach ($itemElement in $itemCommand.CommandElements) {
			if ($itemElement -is [Management.Automation.Language.StringConstantExpressionAst] -and $itemElement.Value -eq 'Out-Null') {
				$true
				return
			}
		}
	}

	$false
}

function New-Ps1OutNullDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidOutNull'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1OutNullDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	$isModuleFile = $normalized -match '/d365bap\.tools/(functions|internal)/'
	$isLintTooling = $normalized -match '/build/ps1-lint/'
	if (-not $isModuleFile -and -not $isLintTooling) { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	if (Test-Ps1OutNullShadowed -Analysis $Analysis) { return }

	foreach ($itemCommand in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
		$commandName = $itemCommand.GetCommandName()
		if ($null -eq $commandName) { continue }
		if (($commandName -split '\\')[-1] -ine 'Out-Null') { continue }

		New-Ps1OutNullDiagnostic -Path $Path -Extent $itemCommand.Extent -Message 'Do not discard output with Out-Null. Redirect it to $null instead: <expression> > $null.'
	}
}
