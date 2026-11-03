function Test-Ps1SelectObjectScriptBlock {
	param($Value)
	$Value -is [Management.Automation.Language.PipelineAst] -and
	$Value.PipelineElements.Count -eq 1 -and
	$Value.PipelineElements[0] -is [Management.Automation.Language.CommandExpressionAst] -and
	$Value.PipelineElements[0].Expression -is [Management.Automation.Language.ScriptBlockExpressionAst]
}

function Get-Ps1SelectObjectProjection {
	param($Command)
	$name = $Command.GetCommandName()
	if ($name -notin @('Select-Object', 'Microsoft.PowerShell.Utility\Select-Object')) { return }
	$colElements = @($Command.CommandElements)
	$argument = $null; $explicit = $false; $unsupported = $false
	for ($i = 1; $i -lt $colElements.Count; $i++) {
		$element = $colElements[$i]
		if ($element -is [Management.Automation.Language.CommandParameterAst]) {
			$parameter = $element.ParameterName
			if ('Property'.StartsWith($parameter, [StringComparison]::OrdinalIgnoreCase)) {
				if ($null -ne $argument) { $unsupported = $true }
				$explicit = $parameter -ieq 'Property'
				if ($element.Argument) { $argument = $element.Argument }
				elseif ($i + 1 -lt $colElements.Count -and $colElements[$i + 1] -isnot [Management.Automation.Language.CommandParameterAst]) { $i++; $argument = $colElements[$i] }
				else { $unsupported = $true }
			}
			elseif ($parameter -in @('First', 'Skip', 'Last', 'ExpandProperty', 'ExcludeProperty', 'InputObject', 'Index', 'SkipLast', 'ErrorAction', 'WarningAction', 'InformationAction', 'ProgressAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable')) {
				if (-not $element.Argument) {
					if ($i + 1 -lt $colElements.Count -and $colElements[$i + 1] -isnot [Management.Automation.Language.CommandParameterAst]) { $i++ }
					else { $unsupported = $true }
				}
			}
			elseif ($parameter -notin @('Unique', 'Wait', 'CaseInsensitive', 'Verbose', 'Debug')) { $unsupported = $true }
		}
		elseif ($element -is [Management.Automation.Language.VariableExpressionAst] -and $element.Splatted) { $unsupported = $true }
		elseif ($null -eq $argument) { $argument = $element }
		else { $unsupported = $true }
	}
	$properties = if ($argument -is [Management.Automation.Language.ArrayLiteralAst]) { @($argument.Elements) } elseif ($argument) { @($argument) } else { @() }
	[pscustomobject]@{ Argument = $argument; Properties = $properties; Explicit = $explicit; Unsupported = $unsupported }
}

function Get-Ps1SelectObjectMessage {
	param($Projection)
	if ($Projection.Unsupported) { 'Unsupported Select-Object form. Use an explicit -Property list and named parameters without splatting.'; return }
	if ($Projection.Argument -and -not $Projection.Explicit) { 'Use the full -Property parameter for Select-Object projections.'; return }
	foreach ($itemProperty in $Projection.Properties) {
		if ($itemProperty -is [Management.Automation.Language.HashtableAst]) {
			$tmpKeys = @($itemProperty.KeyValuePairs | ForEach-Object { $_.Item1.Value })
			$tmpExpression = @($itemProperty.KeyValuePairs | Where-Object { $_.Item1.Value -ieq 'Expression' })
			if ($tmpKeys.Count -ne 2 -or $tmpKeys[0] -ine 'Name' -or $tmpKeys[1] -ine 'Expression' -or $tmpExpression.Count -ne 1 -or -not (Test-Ps1SelectObjectScriptBlock $tmpExpression[0].Item2)) {
				'Use full Name then Expression keys and a scriptblock Expression for calculated properties.'; return
			}
		}
		elseif ($itemProperty -isnot [Management.Automation.Language.StringConstantExpressionAst]) {
			'Unsupported Select-Object projection. Use a literal property list with -Property.'; return
		}
	}
	$colProperties = @($Projection.Properties)
	if (@($colProperties | Where-Object { $_ -is [Management.Automation.Language.HashtableAst] }).Count -eq 0) { return }
	for ($i = 1; $i -lt $colProperties.Count; $i++) {
		if ($colProperties[$i].Extent.StartLineNumber -le $colProperties[$i - 1].Extent.EndLineNumber) {
			'Put each Select-Object property on its own line when using a calculated property.'; return
		}
	}
}

function Get-Ps1StandardSelectObjectDiagnostic {
	param([hashtable] $Analysis)
	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }
	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst)) {
		$projection = Get-Ps1SelectObjectProjection $itemCommand
		if ($null -eq $projection) { continue }
		$message = Get-Ps1SelectObjectMessage $projection
		if ($message) { New-Ps1Diagnostic $Analysis.Path 'PSUseStandardSelectObject' $message $itemCommand.Extent }
	}
}
