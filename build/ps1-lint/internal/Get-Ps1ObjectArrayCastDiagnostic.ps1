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

function New-Ps1ObjectArrayCastDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSAvoidObjectArrayCast'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ObjectArrayCastDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemConvert in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ConvertExpressionAst] }, $true)) {
		if ($itemConvert.Type.TypeName.FullName -notmatch '(?i)^(system\.)?object\[\]$') { continue }
		if ($itemConvert.Parent -is [Management.Automation.Language.ParameterAst]) { continue }
		if (Test-Ps1OutputTypeAncestor -Node $itemConvert) { continue }

		New-Ps1ObjectArrayCastDiagnostic -Path $Path -Extent $itemConvert.Extent -Message 'Do not cast to [object[]]. @() already returns an array and the element type adds nothing.'
	}
}
