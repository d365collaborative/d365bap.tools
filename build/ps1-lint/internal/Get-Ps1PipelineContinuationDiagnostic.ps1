function Get-Ps1PipelineContinuationDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'ModuleSource')) { return }

	$colPipes = @(Get-Ps1TokenNode $Analysis Pipe)

	$colPipelines = @(Get-Ps1AstNode $Analysis PipelineAst | Where-Object { $_.PipelineElements.Count -gt 1 })
	foreach ($itemPipeline in $colPipelines) {
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

			$tmpClosingText = "$($previous.Extent.Text)".TrimEnd()
			$hasClosingBrace = $tmpClosingText.EndsWith('}')

			if ($previous.Extent.StartLineNumber -ne $previous.Extent.EndLineNumber -and $hasClosingBrace) {
				$isClosingLine = $pipe.Extent.StartLineNumber -eq $previous.Extent.EndLineNumber -and
				$next.Extent.StartLineNumber -eq $pipe.Extent.EndLineNumber
				if ($isClosingLine) { continue }

				New-Ps1Diagnostic $Path 'PSUsePipelineContinuationBreak' 'Keep `|` and the next command on the closing brace line of a multiline hashtable element: } | ConvertTo-Json.' $pipe.Extent
				break
			}

			if ($previous.Extent.EndLineNumber -eq $next.Extent.StartLineNumber) {
				New-Ps1Diagnostic $Path 'PSUsePipelineContinuationBreak' 'Break the pipeline after `|`: put the pipe at the end of the line and start the next command on a new line.' $pipe.Extent
				break
			}

			if ($pipe.Extent.StartLineNumber -ne $previous.Extent.EndLineNumber) {
				New-Ps1Diagnostic $Path 'PSUsePipelineContinuationBreak' 'Move `|` to the end of the previous line and start the next command on a new line.' $pipe.Extent
				break
			}
		}
	}
}
