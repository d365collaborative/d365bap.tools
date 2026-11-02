function Test-Ps1ApiVersionLiteral {
	param($Node)

	$Node -is [Management.Automation.Language.StringConstantExpressionAst] -and
	$Node.Value -match '^\d{4}-\d{2}-\d{2}(-preview)?$'
}

function New-Ps1CentralApiVersionDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseCentralApiVersion'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1CentralApiVersionDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/tests/') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemString in $Analysis.Ast.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.StringConstantExpressionAst] -or
				$Node -is [Management.Automation.Language.ExpandableStringExpressionAst]
			}, $true)) {
		if ($itemString.StringConstantType -in @('SingleQuotedHereString', 'DoubleQuotedHereString')) { continue }
		if ($itemString.Value -notmatch '(?i)api-version=[0-9]') { continue }

		New-Ps1CentralApiVersionDiagnostic -Path $Path `
			-Extent $itemString.Extent `
			-Message 'Do not write the API version into a request URL. Read it from $script:BapApiVersions so the registry stays the only source.'
	}

	if ($normalized -match '/d365bap\.tools/internal/scripts/initialize-sdk\.ps1$') { return }

	foreach ($itemAssignment in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
		if ($itemAssignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
		if ($itemAssignment.Left.VariablePath.UserPath -notmatch '(?i)apiversion$') { continue }

		$right = $itemAssignment.Right
		if ($right -is [Management.Automation.Language.CommandExpressionAst]) {
			$right = $right.Expression
		}
		elseif ($right -is [Management.Automation.Language.PipelineAst] -and
			$right.PipelineElements.Count -eq 1 -and
			$right.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst]) {
			$right = $right.PipelineElements[0].Expression
		}

		$isLiteral = Test-Ps1ApiVersionLiteral $right
		if (-not $isLiteral -and $right -is [Management.Automation.Language.IfStatementAst]) {
			$isLiteral = @($right.FindAll({ param($Node) Test-Ps1ApiVersionLiteral $Node }, $true)).Count -gt 0
		}
		if (-not $isLiteral) { continue }

		New-Ps1CentralApiVersionDiagnostic -Path $Path `
			-Extent $itemAssignment.Extent `
			-Message 'Do not assign an API version literal to this variable. Read it from $script:BapApiVersions so the registry stays the only source.'
	}
}
