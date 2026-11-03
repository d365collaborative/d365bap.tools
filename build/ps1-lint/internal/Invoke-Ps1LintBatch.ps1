<#
	.SYNOPSIS
		Formats and analyzes files in one bounded batch.

	.DESCRIPTION
		Runs the formatter and the analyzer in one process and reads files in
		bounded chunks. Every file has its own try/catch. Analysis uses the
		formatted text. Formatting and analysis failures set separate result
		flags.

	.PARAMETER Path
		The files to lint.

	.PARAMETER CheckOnly
		Never write a file. A file that needs formatting still counts as a
		formatting failure.

	.PARAMETER BatchSize
		Number of files held in memory at once.

		Default: 32.

	.PARAMETER AnalyzerSettingsPath
		The analyzer settings file.

		Default: Ps1AnalyzerSettings.psd1.

	.PARAMETER FormatSettingsPath
		The formatter settings file.

		Default: Ps1FormatSettings.psd1.

	.EXAMPLE
		PS C:\> Invoke-Ps1LintBatch -Path .\script.ps1 -CheckOnly

		It checks the file without writing it.
		It will use -Path .\script.ps1.
		It will use -CheckOnly.
		It will use -BatchSize 32.
		It will use -AnalyzerSettingsPath Ps1AnalyzerSettings.psd1.
		It will use -FormatSettingsPath Ps1FormatSettings.psd1.

	.OUTPUTS
		PSCustomObject with the two failure flags and the diagnostics.
#>
function Invoke-Ps1LintBatch {
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string[]] $Path,
		[switch] $CheckOnly,
		[ValidateRange(1, 512)]
		[int] $BatchSize = 32,
		[ValidateNotNullOrEmpty()]
		[string] $AnalyzerSettingsPath = (Join-Path $PSScriptRoot 'Ps1AnalyzerSettings.psd1'),
		[ValidateNotNullOrEmpty()]
		[string] $FormatSettingsPath = (Join-Path $PSScriptRoot 'Ps1FormatSettings.psd1')
	)

	$colFiles = [System.Collections.Generic.List[string]]::new()
	$hashSeen = @{}

	foreach ($itemPath in @($Path)) {
		if ([string]::IsNullOrWhiteSpace($itemPath)) { continue }
		if ($itemPath -notmatch '\.(ps1|psm1|psd1)$') { continue }
		if (-not (Test-Path -LiteralPath $itemPath `
					-PathType Leaf)) { continue }

		$full = (Resolve-Path -LiteralPath $itemPath).Path
		if ($hashSeen.ContainsKey($full)) { continue }

		$hashSeen[$full] = $true
		$colFiles.Add($full) > $null
	}

	$objUtf8Bom = [System.Text.UTF8Encoding]::new($true)
	$colFormatted = [System.Collections.Generic.List[string]]::new()
	$colFormatFailures = [System.Collections.Generic.List[string]]::new()
	$colDiagnostics = [System.Collections.Generic.List[object]]::new()
	$colFailedFiles = [System.Collections.Generic.List[string]]::new()
	$objCacheSession = $null

	if ($colFiles.Count -gt 0) {
		$objAnalyzer = New-Ps1Analyzer -SettingsPath $AnalyzerSettingsPath
		$objCacheSession = New-Ps1AnalysisCacheSession -Analyzer $objAnalyzer
	}

	for ($offset = 0; $offset -lt $colFiles.Count; $offset += $BatchSize) {
		$lastIndex = [Math]::Min($offset + $BatchSize, $colFiles.Count) - 1
		$tmpChunk = @($colFiles[$offset..$lastIndex])
		$tmpContent = @{}

		foreach ($itemFile in $tmpChunk) {
			if ($itemFile -notmatch '\.ps1$') { continue }

			try {
				$objContent = Get-Ps1FormattedContent -Path $itemFile `
					-SettingsPath $FormatSettingsPath
				$tmpContent[$itemFile] = $objContent.Content

				if (-not $objContent.Changed) { continue }

				if (-not $CheckOnly) {
					[System.IO.File]::WriteAllText($itemFile, $objContent.Content, $objUtf8Bom)
				}

				$colFormatted.Add($itemFile) > $null
				Write-Host "  formatted: $itemFile"
			}
			catch {
				$colFormatFailures.Add("$itemFile : $($_.Exception.Message)") > $null
				Write-Host "  formatting failed: $itemFile : $($_.Exception.Message)"
			}
		}

		foreach ($itemFile in $tmpChunk) {
			try {
				$objFileResult = Invoke-Ps1Analysis -Path $itemFile `
					-Analyzer $objAnalyzer `
					-ContentByPath $tmpContent `
					-AnalysisCache $objCacheSession `
					-SkipCustomRules:($itemFile -notmatch '\.ps1$')

				$colDiagnostics.AddRange(@($objFileResult.Diagnostics))

				if ($objFileResult.Failed) {
					$colFailedFiles.Add($itemFile) > $null
				}
			}
			catch {
				$colFailedFiles.Add($itemFile) > $null
				$colDiagnostics.Add((New-Ps1Diagnostic -Path $itemFile `
							-Rule 'PSLintBatchError' `
							-Message "Analysis failed: $($_.Exception.Message)"))
			}
		}
	}

	if ($colDiagnostics.Count -gt 0) {
		$colDiagnostics |
		Format-Table -AutoSize `
			-Wrap |
		Out-String |
		Write-Host
	}

	Complete-Ps1AnalysisCacheSession -Session $objCacheSession

	if ($colFormatFailures.Count -gt 0) {
		Write-Host "$($colFormatFailures.Count) file(s) could not be formatted."
	}

	if ($CheckOnly -and $colFormatted.Count -gt 0) {
		Write-Host "$($colFormatted.Count) file(s) need formatting. Check-only mode wrote no files."
	}

	if ($colFailedFiles.Count -gt 0) {
		Write-Host "$($colFailedFiles.Count) file(s) failed PSScriptAnalyzer or repository rules."
	}

	[pscustomobject]@{
		Files          = $colFiles.Count
		Formatted      = @($colFormatted)
		FormatFailures = @($colFormatFailures)
		Diagnostics    = @($colDiagnostics)
		FailedFiles    = @($colFailedFiles)
		FormatFailed   = ($colFormatted.Count -gt 0 -or $colFormatFailures.Count -gt 0)
		AnalysisFailed = ($colFailedFiles.Count -gt 0)
		CheckOnly      = [bool] $CheckOnly
	}
}

. "$PSScriptRoot/Get-Ps1FormattedContent.ps1"
. "$PSScriptRoot/Invoke-Ps1Analysis.ps1"
