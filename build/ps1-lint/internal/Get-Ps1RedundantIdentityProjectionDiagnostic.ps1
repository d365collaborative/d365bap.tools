function Test-Ps1IdentityProjection {
	param($Command, $Argument)

	$pattern = '^(?<name>[A-Za-z_][A-Za-z0-9_]*)\s+as\s+\k<name>$'
	$colNames = [System.Collections.Generic.List[string]]::new()

	if ($Argument -is [Management.Automation.Language.ArrayLiteralAst]) {
		foreach ($itemElement in $Argument.Elements) {
			if ($itemElement -isnot [Management.Automation.Language.StringConstantExpressionAst]) { $false; return }
			if (-not ($itemElement.Value -cmatch $pattern)) { $false; return }
			$colNames.Add($Matches['name'])
		}
	}
	else {
		if ($Argument -isnot [Management.Automation.Language.StringConstantExpressionAst]) { $false; return }
		if (-not ($Argument.Value -cmatch $pattern)) { $false; return }
		$colNames.Add($Matches['name'])
	}

	if ($colNames.Count -eq 0) { $false; return }

	$parent = $Command.Parent
	if ($parent -isnot [Management.Automation.Language.PipelineAst]) { $false; return }

	$colPipeline = @($parent.PipelineElements)
	$index = [Array]::IndexOf($colPipeline, $Command)
	if ($index -le 0) { $false; return }

	$previous = $colPipeline[$index - 1]
	if ($previous -isnot [Management.Automation.Language.CommandExpressionAst]) { $false; return }

	$convert = $previous.Expression
	if ($convert -isnot [Management.Automation.Language.ConvertExpressionAst]) { $false; return }
	if ($convert.Type.TypeName.FullName -notmatch '(?i)^(system\.management\.automation\.)?pscustomobject$') { $false; return }

	$hashTable = $convert.Child
	if ($hashTable -isnot [Management.Automation.Language.HashtableAst]) { $false; return }

	$colKeys = [System.Collections.Generic.List[string]]::new()
	foreach ($itemPair in $hashTable.KeyValuePairs) {
		if ($itemPair.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]) { $false; return }
		$colKeys.Add($itemPair.Item1.Value)
	}

	if ($colKeys.Count -ne $colNames.Count) { $false; return }

	$colKeys.Sort([StringComparer]::Ordinal)
	$colNames.Sort([StringComparer]::Ordinal)
	for ($index = 0; $index -lt $colKeys.Count; $index++) {
		if ($colKeys[$index] -cne $colNames[$index]) { $false; return }
	}

	$true
}

function New-Ps1RedundantIdentityProjectionDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidRedundantIdentityProjection'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ProjectionOwnerFunction {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.FunctionDefinitionAst]) {
			$parent
			return
		}
		$parent = $parent.Parent
	}
	$null
}

function Get-Ps1ProjectionSource {
	param($Command)

	$parent = $Command.Parent
	if ($parent -isnot [Management.Automation.Language.PipelineAst]) { $null; return }

	$colElements = @($parent.PipelineElements)
	$index = [Array]::IndexOf($colElements, $Command)
	if ($index -le 0) { $null; return }

	$previous = $colElements[$index - 1]
	if ($previous -isnot [Management.Automation.Language.CommandExpressionAst]) { $null; return }
	if ($previous.Expression -isnot [Management.Automation.Language.VariableExpressionAst]) { $null; return }
	$previous.Expression
}

function Get-Ps1RedundantIdentityProjectionDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemFunction in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		$tmpAssigned = @{}
		foreach ($itemAssignment in @($itemFunction.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.AssignmentStatementAst] }, $true) | Sort-Object { $_.Extent.StartOffset })) {
			if ((Get-Ps1ProjectionOwnerFunction -Node $itemAssignment) -ne $itemFunction) { continue }
			if ($itemAssignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }

			$tmpSelects = @($itemAssignment.Right.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] -and $Node.GetCommandName() -eq 'Select-PSFObject' }, $true))
			if ($tmpSelects.Count -eq 0) { continue }

			$tmpAssigned[$itemAssignment.Left.VariablePath.UserPath] = $itemAssignment.Extent.StartOffset
		}

		foreach ($itemCommand in $itemFunction.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
			$commandName = $itemCommand.GetCommandName()
			if ($null -eq $commandName) { continue }
			if (($commandName -split '\\')[-1] -ine 'Select-PSFObject') { continue }
			if ((Get-Ps1ProjectionOwnerFunction -Node $itemCommand) -ne $itemFunction) { continue }

			$source = Get-Ps1ProjectionSource -Command $itemCommand
			if ($null -ne $source) {
				$sourceName = $source.VariablePath.UserPath

				$selfSelect = $false
				$node = $itemCommand
				while ($null -ne $node -and
					$node -isnot [Management.Automation.Language.AssignmentStatementAst] -and
					$node -isnot [Management.Automation.Language.FunctionDefinitionAst]) {
					$node = $node.Parent
				}
				if ($node -is [Management.Automation.Language.AssignmentStatementAst] -and
					$node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
					$node.Left.VariablePath.UserPath -eq $sourceName) {
					$selfSelect = $true
				}

				$doubleSelect = $tmpAssigned.ContainsKey($sourceName) -and $tmpAssigned[$sourceName] -lt $itemCommand.Extent.StartOffset
				if ($doubleSelect -or $selfSelect) {
					New-Ps1RedundantIdentityProjectionDiagnostic -Path $Path -Extent $itemCommand.Extent -Message 'Do not select an already selected variable again. Combine the projections into one Select-PSFObject call.'
					continue
				}
			}

			$tmpElements = @($itemCommand.CommandElements)
			for ($index = 0; $index -lt $tmpElements.Count; $index++) {
				$element = $tmpElements[$index]
				if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
				if ($element.ParameterName -ine 'Property') { continue }

				$argument = if ($null -ne $element.Argument) { $element.Argument } elseif ($index + 1 -lt $tmpElements.Count) { $tmpElements[$index + 1] } else { $null }
				if ($null -eq $argument) { continue }

				if (-not (Test-Ps1IdentityProjection -Command $itemCommand -Argument $argument)) { continue }

				New-Ps1RedundantIdentityProjectionDiagnostic -Path $Path -Extent $element.Extent -Message 'Drop -Property and keep -TypeName (or set PSTypeName in the literal); every property is already projected under the same name.'
			}
		}
	}
}
