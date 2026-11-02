function New-Ps1EmptyLineAfterContinuationDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseEmptyLineAfterContinuation'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1EmptyLineAfterContinuationDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$colContinuations = @($Analysis.Tokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::LineContinuation })
	if ($colContinuations.Count -eq 0) { return }

	$scriptBlock = { param($Node) $Node -is [Management.Automation.Language.NamedBlockAst] -or $Node -is [Management.Automation.Language.StatementBlockAst] }
	foreach ($itemBlock in $Analysis.Ast.FindAll($scriptBlock, $true)) {
		$tmpStatements = @($itemBlock.Statements)
		for ($index = 0; $index -lt $tmpStatements.Count - 1; $index++) {
			$current = $tmpStatements[$index]
			$next = $tmpStatements[$index + 1]
			if ($next.Extent.StartLineNumber -ne ($current.Extent.EndLineNumber + 1)) { continue }

			$continuationLine = $current.Extent.EndLineNumber - 1
			$hasContinuation = $false
			foreach ($itemContinuation in $colContinuations) {
				if ($itemContinuation.Extent.StartLineNumber -ne $continuationLine) { continue }
				if ($itemContinuation.Extent.StartOffset -lt $current.Extent.StartOffset) { continue }
				if ($itemContinuation.Extent.EndOffset -gt $current.Extent.EndOffset) { continue }
				$hasContinuation = $true
				break
			}
			if (-not $hasContinuation) { continue }

			New-Ps1EmptyLineAfterContinuationDiagnostic -Path $Path `
				-Extent $next.Extent `
				-Message 'Add an empty line after the line continuation so the next statement is clearly separate.'
		}
	}
}
