function Get-Ps1Analysis {
	param([string] $Path)
	$tokens = $null
	$ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$null)
	$analysis = @{ Path = $Path; Ast = $ast; Tokens = $tokens }
	$analysis.CommentGroups = @(Get-Ps1CommentGroup -Analysis $analysis)
	$analysis.HelpSections = @(Get-Ps1HelpSection -Analysis $analysis)
	$analysis
}

function Get-Ps1AnalysisWorker {
	$worker = @{ RuntimeAliases = @{}; CommonParameters = @{}; Cache = @{}; Configuration = @{} }
	foreach ($alias in Get-Alias) { $worker.RuntimeAliases[$alias.Name] = $alias.Definition }
	foreach ($parameter in (Get-Command Microsoft.PowerShell.Management\Remove-Item).Parameters.Values) {
		if ([Management.Automation.Cmdlet]::CommonParameters.Contains($parameter.Name) -or
			[Management.Automation.Cmdlet]::OptionalCommonParameters.Contains($parameter.Name)) {
			$worker.CommonParameters[$parameter.Name] = $parameter
		}
	}
	$worker
}
