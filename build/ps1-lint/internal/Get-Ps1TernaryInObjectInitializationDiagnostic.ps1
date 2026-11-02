function New-Ps1TernaryInObjectInitializationDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseTernaryInObjectInitialization'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1TernaryInObjectInitializationDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$message = 'Use a ternary operator for an if expression in an object initializer: <condition> ? <true value> : <else value>.'

	foreach ($itemHashtable in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.HashtableAst] }, $true)) {
		foreach ($itemPair in $itemHashtable.KeyValuePairs) {
			if ($itemPair.Item2 -isnot [Management.Automation.Language.IfStatementAst]) { continue }
			if ($null -eq $itemPair.Item2.ElseClause) { continue }

			New-Ps1TernaryInObjectInitializationDiagnostic -Path $Path `
				-Extent $itemPair.Item2.Extent `
				-Message $message
		}
	}
}
