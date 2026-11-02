function Test-Ps1ComplexArrayElement {
	param($Node)

	if ($Node -is [Management.Automation.Language.HashtableAst]) { $true; return }
	if ($Node -is [Management.Automation.Language.ScriptBlockExpressionAst]) { $true; return }
	if ($Node -is [Management.Automation.Language.ConvertExpressionAst] -and
		$Node.Child -is [Management.Automation.Language.HashtableAst]) { $true; return }

	$false
}

function New-Ps1ComplexArrayElementDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseOneComplexArrayElementPerLine'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ComplexArrayElementDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemLiteral in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ArrayLiteralAst] }, $true)) {
		$tmpElements = @($itemLiteral.Elements)
		if ($tmpElements.Count -le 1) { continue }

		$tmpComplex = @($tmpElements | Where-Object { Test-Ps1ComplexArrayElement -Node $_ })
		if ($tmpComplex.Count -le 1) { continue }

		for ($index = 0; $index -lt ($tmpComplex.Count - 1); $index++) {
			if ($tmpComplex[$index].Extent.StartLineNumber -ne $tmpComplex[$index + 1].Extent.StartLineNumber) { continue }

			New-Ps1ComplexArrayElementDiagnostic -Path $Path `
				-Extent $itemLiteral.Extent `
				-Message 'Put each complex array element on its own line. A hashtable or scriptblock element makes a crowded line hard to read.'
			break
		}
	}
}
