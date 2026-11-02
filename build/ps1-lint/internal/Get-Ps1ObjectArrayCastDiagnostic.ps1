function Test-Ps1OutputTypeAncestor {
	param($Node)

	$parent = $Node.Parent
	while ($null -ne $parent) {
		if ($parent -is [Management.Automation.Language.AttributeAst] -and $parent.TypeName.FullName -match '^OutputType') {
			$true
			return
		}
		$parent = $parent.Parent
	}
	$false
}

function Get-Ps1ObjectArrayCastDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	foreach ($itemConvert in @(Get-Ps1AstNode $Analysis ConvertExpressionAst)) {
		if ($itemConvert.Type.TypeName.FullName -notmatch '(?i)^(system\.)?object\[\]$') { continue }
		if ($itemConvert.Parent -is [Management.Automation.Language.ParameterAst]) { continue }
		if (Test-Ps1OutputTypeAncestor -Node $itemConvert) { continue }

		New-Ps1Diagnostic $Path 'PSAvoidObjectArrayCast' 'Do not cast to [object[]]. @() already returns an array and the element type adds nothing.' $itemConvert.Extent
	}
}
