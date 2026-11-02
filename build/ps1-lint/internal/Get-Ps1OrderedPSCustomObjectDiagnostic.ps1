function Get-Ps1OrderedChild {
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
	$value
}

function New-Ps1OrderedPSCustomObjectDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseOrderedPSCustomObject'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1OrderedPSCustomObjectDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	foreach ($itemConvert in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.ConvertExpressionAst] }, $true)) {
		if ($itemConvert.Type.TypeName.FullName -notmatch '(?i)^(system\.management\.automation\.)?pscustomobject$') { continue }

		$child = Get-Ps1OrderedChild -Node $itemConvert.Child
		if ($child -isnot [Management.Automation.Language.HashtableAst]) { continue }

		New-Ps1OrderedPSCustomObjectDiagnostic -Path $Path -Extent $itemConvert.Extent -Message 'Build the object through [ordered] so property order is explicit: [pscustomobject][ordered]@{ ... }.'
	}
}
