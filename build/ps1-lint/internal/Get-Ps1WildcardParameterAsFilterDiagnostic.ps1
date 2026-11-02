function Get-Ps1WildcardFilterAttribute {
	param($Parameter)

	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [Management.Automation.SupportsWildcardsAttribute] -or
				$_.TypeName.FullName -in @('SupportsWildcards', 'SupportsWildcardsAttribute', 'System.Management.Automation.SupportsWildcardsAttribute')
			)
		})[0]
}

function Test-Ps1WildcardFilterParameter {
	param($Parameter)

	if ($null -ne (Get-Ps1WildcardFilterAttribute -Parameter $Parameter)) {
		$true
		return
	}

	$Parameter.DefaultValue -is [Management.Automation.Language.StringConstantExpressionAst] -and
	$Parameter.DefaultValue.Value.Contains('*')
}

function Get-Ps1WildcardFilterOwnerFunction {
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

function New-Ps1WildcardFilterDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseWildcardParameterAsFilter'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1WildcardParameterAsFilterDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal/functions)/[^/]+\.ps1$') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }

	foreach ($itemFunction in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		if ($null -eq $itemFunction.Body.ParamBlock) { continue }

		$tmpWildcard = @{}
		foreach ($itemParameter in $itemFunction.Body.ParamBlock.Parameters) {
			if (-not (Test-Ps1WildcardFilterParameter -Parameter $itemParameter)) { continue }
			$tmpWildcard[$itemParameter.Name.VariablePath.UserPath] = $true
		}
		if ($tmpWildcard.Count -eq 0) { continue }

		$tmpAssigned = @{}
		foreach ($itemAssignment in $itemFunction.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
			if ((Get-Ps1WildcardFilterOwnerFunction -Node $itemAssignment) -ne $itemFunction) { continue }
			if ($itemAssignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
			$tmpAssigned[$itemAssignment.Left.VariablePath.UserPath] = $true
		}

		foreach ($itemBinary in $itemFunction.Body.FindAll({ param($Node) $Node -is [Management.Automation.Language.BinaryExpressionAst] }, $true)) {
			if ((Get-Ps1WildcardFilterOwnerFunction -Node $itemBinary) -ne $itemFunction) { continue }
			if ("$($itemBinary.Operator)" -notin @('Ieq', 'Ine', 'Ceq', 'Cne')) { continue }

			$name = $null
			foreach ($itemSide in @(@{ Node = $itemBinary.Left; Other = $itemBinary.Right }, @{ Node = $itemBinary.Right; Other = $itemBinary.Left })) {
				if (-not ($itemSide.Node -is [Management.Automation.Language.VariableExpressionAst])) { continue }
				if ($itemSide.Node.VariablePath.UserPath.Contains(':')) { continue }
				if (-not $tmpWildcard.ContainsKey($itemSide.Node.VariablePath.UserPath)) { continue }
				if ($tmpAssigned.ContainsKey($itemSide.Node.VariablePath.UserPath)) { continue }
				if ($itemSide.Other -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
				if ($itemSide.Other.Value -ne '*') { continue }
				$name = $itemSide.Node.VariablePath.UserPath
			}

			if ($null -eq $name) { continue }

			New-Ps1WildcardFilterDiagnostic -Path $Path -Extent $itemBinary.Extent -Message "Parameter -$name is a wildcard filter. Do not compare it with the literal '*'; pass the value to the filter."
		}
	}
}
