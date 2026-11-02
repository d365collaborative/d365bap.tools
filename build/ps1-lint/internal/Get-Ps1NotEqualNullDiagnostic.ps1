function Test-Ps1NullOperand {
	param($Node)

	$value = $Node
	while ($true) {
		if ($value -is [Management.Automation.Language.ParenExpressionAst]) {
			$value = $value.Pipeline
			continue
		}
		if ($value -is [Management.Automation.Language.PipelineAst] -and
			$value.PipelineElements.Count -eq 1 -and
			$value.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
			$value = $value.PipelineElements[0].Expression
			continue
		}
		break
	}

	$value -is [Management.Automation.Language.VariableExpressionAst] -and
	$value.VariablePath.UserPath -ieq 'null'
}

function New-Ps1NotEqualNullDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidNotEqualNull'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1NotEqualNullDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemBinary in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.BinaryExpressionAst] }, $true)) {
		if ("$($itemBinary.Operator)" -notin @('Ine', 'Cne')) { continue }
		if (-not (Test-Ps1NullOperand -Node $itemBinary.Left)) { continue }

		New-Ps1NotEqualNullDiagnostic -Path $Path `
			-Extent $itemBinary.Extent `
			-Message 'Do not test against $null with -ne or -cne. Use -Not ($null -eq <expression>) instead.'
	}
}
