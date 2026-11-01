function Get-Ps1Analysis {
	param([string] $Path)
	$tokens = $null
	$ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$null)
	$hashAnalysis = @{ Path = $Path; Ast = $ast; Tokens = $tokens }
	$hashAnalysis.CommentGroups = @(Get-Ps1CommentGroup -Analysis $hashAnalysis)
	$hashAnalysis.HelpSections = @(Get-Ps1HelpSection -Analysis $hashAnalysis)
	$hashAnalysis
}

function Get-Ps1AnalysisWorker {
	$hashWorker = @{ RuntimeAliases = @{}; CommonParameters = @{}; Cache = @{}; Configuration = @{} }
	foreach ($itemAlias in Get-Alias) { $hashWorker.RuntimeAliases[$itemAlias.Name] = $itemAlias.Definition }
	foreach ($itemParameter in (Get-Command Microsoft.PowerShell.Management\Remove-Item).Parameters.Values) {
		if ([Management.Automation.Cmdlet]::CommonParameters.Contains($itemParameter.Name) -or
			[Management.Automation.Cmdlet]::OptionalCommonParameters.Contains($itemParameter.Name)) {
			$hashWorker.CommonParameters[$itemParameter.Name] = $itemParameter
		}
	}
	$hashWorker
}
