function New-Ps1PipelineContinuationDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUsePipelineContinuationBreak'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1PipelineContinuationDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal)/') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }
	if ($normalized -match '/d365bap\.tools/internal/tepp/') { return }

	$colPipes = @($Analysis.Tokens | Where-Object { $_.Kind -eq [System.Management.Automation.Language.TokenKind]::Pipe })

	foreach ($itemPipeline in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.PipelineAst] -and $Node.PipelineElements.Count -gt 1 }, $true)) {
		$tmpElements = @($itemPipeline.PipelineElements)

		for ($index = 1; $index -lt $tmpElements.Count; $index++) {
			$previous = $tmpElements[$index - 1]
			$next = $tmpElements[$index]

			$pipe = $null
			foreach ($itemPipe in $colPipes) {
				if ($itemPipe.Extent.StartOffset -lt $previous.Extent.EndOffset) { continue }
				if ($itemPipe.Extent.EndOffset -gt $next.Extent.StartOffset) { continue }
				$pipe = $itemPipe
				break
			}
			if ($null -eq $pipe) { continue }

			if ($previous.Extent.StartLineNumber -ne $previous.Extent.EndLineNumber) {
				$isClosingLine = $pipe.Extent.StartLineNumber -eq $previous.Extent.EndLineNumber -and
				$next.Extent.StartLineNumber -eq $pipe.Extent.EndLineNumber
				if ($isClosingLine) { continue }

				New-Ps1PipelineContinuationDiagnostic -Path $Path `
					-Extent $pipe.Extent `
					-Message 'Keep `|` and the next command on the closing line of a multiline pipeline element: } | ConvertTo-Json.'
				break
			}

			if ($previous.Extent.EndLineNumber -eq $next.Extent.StartLineNumber) {
				New-Ps1PipelineContinuationDiagnostic -Path $Path `
					-Extent $pipe.Extent `
					-Message 'Break the pipeline after `|`: put the pipe at the end of the line and start the next command on a new line.'
				break
			}

			if ($pipe.Extent.StartLineNumber -ne $previous.Extent.EndLineNumber) {
				New-Ps1PipelineContinuationDiagnostic -Path $Path `
					-Extent $pipe.Extent `
					-Message 'Move `|` to the end of the previous line and start the next command on a new line.'
				break
			}
		}
	}
}
