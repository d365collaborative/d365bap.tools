function Get-Ps1AnalyzerSettings {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Path
	)

	Import-PowerShellDataFile -LiteralPath $Path
}

function New-Ps1Analyzer {
	[CmdletBinding()]
	param(
		[string] $SettingsPath = (Join-Path $PSScriptRoot 'Ps1AnalyzerSettings.psd1')
	)

	$hashSettings = Get-Ps1AnalyzerSettings -Path $SettingsPath

	$objVersion = Import-Ps1Analyzer -SettingsPath $SettingsPath

	[pscustomobject]@{
		Settings     = $hashSettings
		SettingsPath = $SettingsPath
		Version      = $objVersion
		Worker       = Get-Ps1AnalysisWorker
	}
}

function Test-Ps1AnalysisFailure {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		$Result,
		[Parameter(Mandatory = $true)]
		[hashtable] $Settings
	)

	$normalized = "$($Result.Path)" -replace '\\', '/'
	$fatal = if ($normalized -match $Settings.ModulePathPattern) {
		$Settings.ModuleFatalSeverity
	}
	else {
		$Settings.DefaultFatalSeverity
	}

	$hasFatalSeverity = @($Result.Diagnostics | Where-Object { $_.Severity -in $fatal }).Count -gt 0
	$hasHighSignal = @($Result.Diagnostics | Where-Object {
			$_.RuleName -in $Settings.HighSignalRule -and $normalized -match $Settings.HighSignalPathPattern
		}).Count -gt 0

	$hasFatalSeverity -or $hasHighSignal
}

function Get-Ps1DiagnosticRule {
	[CmdletBinding()]
	[OutputType([pscustomobject])]
	param()

	# One entry per repository diagnostic. Id names the rule function, Script
	# names the file that defines it, and NeedsWorker requests the shared
	# analysis worker. Loading and dispatch both read this list, so a new rule
	# is registered in one place.
	@(
		[pscustomobject]@{ Id = 'Get-Ps1CommentDiagnostic'; Script = 'Get-Ps1CommentDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1HelpDiagnostic'; Script = 'Get-Ps1HelpDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ParameterContractDiagnostic'; Script = 'Get-Ps1ParameterContractDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ParameterLayoutDiagnostic'; Script = 'Get-Ps1ParameterLayoutDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1StandardPublicOutputDiagnostic'; Script = 'Get-Ps1StandardPublicOutputDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1AddMemberDiagnostic'; Script = 'Get-Ps1AddMemberDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1AccessTokenDiagnostic'; Script = 'Get-Ps1AccessTokenDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1EnvironmentLookupDiagnostic'; Script = 'Get-Ps1EnvironmentLookupDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1VariableNamingDiagnostic'; Script = 'Get-Ps1VariableNamingDiagnostic.ps1'; NeedsWorker = $true }
		[pscustomobject]@{ Id = 'Get-Ps1ShouldProcessDiagnostic'; Script = 'Get-Ps1ShouldProcessDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OutputTypeDiagnostic'; Script = 'Get-Ps1OutputTypeDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1FunctionInterruptDiagnostic'; Script = 'Get-Ps1FunctionInterruptDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ReturnValueDiagnostic'; Script = 'Get-Ps1ReturnValueDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ObjectArrayCastDiagnostic'; Script = 'Get-Ps1ObjectArrayCastDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1WildcardParameterContractDiagnostic'; Script = 'Get-Ps1WildcardParameterContractDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OrderedPSCustomObjectDiagnostic'; Script = 'Get-Ps1OrderedPSCustomObjectDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OutNullDiagnostic'; Script = 'Get-Ps1OutNullDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1LoopAppendDiagnostic'; Script = 'Get-Ps1LoopAppendDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OneParameterPerLineDiagnostic'; Script = 'Get-Ps1OneParameterPerLineDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1NotEqualNullDiagnostic'; Script = 'Get-Ps1NotEqualNullDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ExplicitParameterPresenceDiagnostic'; Script = 'Get-Ps1ExplicitParameterPresenceDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ReturnAfterStopDiagnostic'; Script = 'Get-Ps1ReturnAfterStopDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1PipelineContinuationDiagnostic'; Script = 'Get-Ps1PipelineContinuationDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ComplexArrayElementDiagnostic'; Script = 'Get-Ps1ComplexArrayElementDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1StandardSelectObjectDiagnostic'; Script = 'Get-Ps1StandardSelectObjectDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1AliasDiagnostic'; Script = 'Get-Ps1AliasDiagnostic.ps1'; NeedsWorker = $true }
		[pscustomobject]@{ Id = 'Get-Ps1CentralApiVersionDiagnostic'; Script = 'Get-Ps1CentralApiVersionDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1FormattedUrlDiagnostic'; Script = 'Get-Ps1FormattedUrlDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1MultilineIfExpressionDiagnostic'; Script = 'Get-Ps1MultilineIfExpressionDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1MultilineIfConditionDiagnostic'; Script = 'Get-Ps1MultilineIfConditionDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1TernaryInObjectInitializationDiagnostic'; Script = 'Get-Ps1TernaryInObjectInitializationDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1DirectStringCheckDiagnostic'; Script = 'Get-Ps1DirectStringCheckDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1HeadersVariableDiagnostic'; Script = 'Get-Ps1HeadersVariableDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ModuleSplattingDiagnostic'; Script = 'Get-Ps1ModuleSplattingDiagnostic.ps1'; NeedsWorker = $true }
		[pscustomobject]@{ Id = 'Get-Ps1EmptyLineAfterContinuationDiagnostic'; Script = 'Get-Ps1EmptyLineAfterContinuationDiagnostic.ps1'; NeedsWorker = $false }
	)
}

# PSScriptAnalyzer leaves ScriptName empty when it analyzes text instead of a
# path. Report the file name so output keeps one row per file.
function New-Ps1AnalyzerDiagnostic {
	param(
		[string] $Path,
		$Diagnostic
	)

	if (-not [string]::IsNullOrEmpty($Diagnostic.ScriptName)) {
		$Diagnostic
		return
	}

	[pscustomobject]@{
		RuleName   = $Diagnostic.RuleName
		Severity   = $Diagnostic.Severity
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Diagnostic.Line
		Column     = $Diagnostic.Column
		Message    = $Diagnostic.Message
	}
}

function Invoke-Ps1Analysis {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $Path,
		[Parameter(Mandatory = $true)]
		$Analyzer,
		# Formatted text keyed by absolute path. A key makes the analyzer read
		# the formatted content instead of the file on disk.
		[hashtable] $ContentByPath = @{},
		# Full scans keep the historical built-in-only coverage. Custom rules
		# are adopted as files change, so their existing debt must not fail a
		# module-wide run. The analysis is built in the same built-in-only
		# mode, so the comment groups and help sections that only custom rules
		# read are never built.
		[switch] $SkipCustomRules,
		# A session from New-Ps1AnalysisCacheSession. $null keeps the uncached
		# path. The cache only skips work; every result is validated on read.
		$AnalysisCache
	)

	process {
		foreach ($itemPath in @($Path)) {
			$hasContent = $ContentByPath.ContainsKey($itemPath)
			$cacheSession = $AnalysisCache
			if ($null -ne $cacheSession -and -not $cacheSession.Enabled) { $cacheSession = $null }

			$textHash = $null
			$builtInKey = $null
			$builtInPath = $null
			$customKey = $null
			$customPath = $null
			$builtInEntry = $null
			$customEntry = $null

			if ($null -ne $cacheSession) {
				$tmpText = if ($hasContent) { $ContentByPath[$itemPath] } else { [IO.File]::ReadAllText($itemPath) }
				$textHash = Get-Ps1TextHash -Text $tmpText

				$builtInKey = Get-Ps1AnalysisCacheKey -Session $cacheSession `
					-Kind builtin `
					-Path $itemPath `
					-TextHash $textHash
				$builtInPath = Get-Ps1AnalysisCacheEntryPath -Session $cacheSession `
					-Key $builtInKey
				$builtInEntry = Read-Ps1AnalysisCacheEntry -Session $cacheSession `
					-Key $builtInKey `
					-EntryPath $builtInPath
				if ($null -ne $builtInEntry) { $cacheSession.Hits = $cacheSession.Hits + 1 }
				else { $cacheSession.Misses = $cacheSession.Misses + 1 }

				if (-not $SkipCustomRules) {
					$tmpFingerprint = Get-Ps1AnalysisCacheCustomFingerprint -Session $cacheSession `
						-Path $itemPath `
						-Analyzer $Analyzer
					if ($null -ne $tmpFingerprint) {
						$customKey = Get-Ps1AnalysisCacheKey -Session $cacheSession `
							-Kind custom `
							-Path $itemPath `
							-TextHash $textHash `
							-Fingerprint $tmpFingerprint
						$customPath = Get-Ps1AnalysisCacheEntryPath -Session $cacheSession `
							-Key $customKey
						$customEntry = Read-Ps1AnalysisCacheEntry -Session $cacheSession `
							-Key $customKey `
							-EntryPath $customPath
						if ($null -ne $customEntry) { $cacheSession.Hits = $cacheSession.Hits + 1 }
						else { $cacheSession.Misses = $cacheSession.Misses + 1 }
					}
				}
			}

			# A complete hit skips the parse, the analyzer, and the rules. A
			# parse failure is cached with the entry, so it reproduces the
			# parse-only result without reading the trees again.
			if ($null -ne $builtInEntry -and ($SkipCustomRules -or $null -ne $customEntry)) {
				$tmpCached = [System.Collections.Generic.List[object]]::new()
				$tmpCached.AddRange(@($builtInEntry.Diagnostics))
				if (-not $builtInEntry.ParseFailed -and $null -ne $customEntry) {
					$tmpCached.AddRange(@($customEntry.Diagnostics))
				}

				$result = [pscustomobject]@{
					Path        = $itemPath
					Diagnostics = @($tmpCached)
					Failed      = $false
				}
				# A parse failure always fails, exactly like the uncached path.
				if ($builtInEntry.ParseFailed) {
					$result.Failed = $true
				}
				else {
					$result.Failed = Test-Ps1AnalysisFailure -Result $result `
						-Settings $Analyzer.Settings
				}
				$result
				continue
			}

			$analysis = if ($hasContent) {
				Get-Ps1Analysis -Path $itemPath `
					-Content $ContentByPath[$itemPath] `
					-SkipCustomRules:$SkipCustomRules
			}
			else {
				Get-Ps1Analysis -Path $itemPath `
					-SkipCustomRules:$SkipCustomRules
			}
			$tmpParseDiagnostics = @(Get-Ps1ParseDiagnostic -Analysis $analysis)

			if ($tmpParseDiagnostics.Count -gt 0) {
				if ($null -ne $builtInKey) {
					Write-Ps1AnalysisCacheEntry -Session $cacheSession `
						-Key $builtInKey `
						-EntryPath $builtInPath `
						-Diagnostics $tmpParseDiagnostics `
						-ParseFailed $true
				}
				if ($null -ne $customKey) {
					Write-Ps1AnalysisCacheEntry -Session $cacheSession `
						-Key $customKey `
						-EntryPath $customPath `
						-Diagnostics $tmpParseDiagnostics `
						-ParseFailed $true
				}
				[pscustomobject]@{
					Path        = $itemPath
					Diagnostics = $tmpParseDiagnostics
					Failed      = $true
				}
				continue
			}

			$tmpDiagnostics = [System.Collections.Generic.List[object]]::new()
			if ($null -ne $builtInEntry) {
				$tmpDiagnostics.AddRange(@($builtInEntry.Diagnostics))
			}
			else {
				if ($hasContent) {
					$tmpBuiltIn = @(Invoke-ScriptAnalyzer -ScriptDefinition $ContentByPath[$itemPath] `
							-Severity $Analyzer.Settings.Severity `
							-ExcludeRule $Analyzer.Settings.ExcludeRule `
							-ErrorAction Stop |
						ForEach-Object {
							New-Ps1AnalyzerDiagnostic -Path $itemPath `
								-Diagnostic $_
						})
				}
				else {
					$tmpBuiltIn = @(Invoke-ScriptAnalyzer -Path $itemPath `
							-Recurse `
							-Severity $Analyzer.Settings.Severity `
							-ExcludeRule $Analyzer.Settings.ExcludeRule `
							-ErrorAction Stop)
				}
				if (($itemPath -replace '\\', '/') -match $Analyzer.Settings.ModulePathPattern) {
					$tmpBuiltIn = @($tmpBuiltIn | Where-Object RuleName -ne 'PSShouldProcess')
				}
				$tmpDiagnostics.AddRange($tmpBuiltIn)
				if ($null -ne $builtInKey) {
					Write-Ps1AnalysisCacheEntry -Session $cacheSession `
						-Key $builtInKey `
						-EntryPath $builtInPath `
						-Diagnostics $tmpBuiltIn
				}
			}

			if (-not $SkipCustomRules) {
				if ($null -ne $customEntry) {
					$tmpDiagnostics.AddRange(@($customEntry.Diagnostics))
				}
				else {
					$tmpRuleDiagnostics = [System.Collections.Generic.List[object]]::new()
					foreach ($itemRule in Get-Ps1DiagnosticRule) {
						$tmpRule = @{ Analysis = $analysis }
						if ($itemRule.NeedsWorker) {
							$tmpRule.Worker = $Analyzer.Worker
						}
						$tmpRuleDiagnostics.AddRange(@(& $itemRule.Id @tmpRule))
					}
					$tmpDiagnostics.AddRange($tmpRuleDiagnostics)
					if ($null -ne $customKey) {
						Write-Ps1AnalysisCacheEntry -Session $cacheSession `
							-Key $customKey `
							-EntryPath $customPath `
							-Diagnostics $tmpRuleDiagnostics
					}
				}
			}

			$result = [pscustomobject]@{
				Path        = $itemPath
				Diagnostics = @($tmpDiagnostics)
				Failed      = $false
			}
			$result.Failed = Test-Ps1AnalysisFailure -Result $result `
				-Settings $Analyzer.Settings
			$result
		}
	}
}

foreach ($itemRule in Get-Ps1DiagnosticRule) {
	. (Join-Path $PSScriptRoot $itemRule.Script)
}

. "$PSScriptRoot/Get-Ps1AliasConfiguration.ps1"
. "$PSScriptRoot/Resolve-Ps1AliasCommand.ps1"
. "$PSScriptRoot/Get-Ps1CommentGroup.ps1"
. "$PSScriptRoot/Get-Ps1HelpSection.ps1"
. "$PSScriptRoot/Get-Ps1Analysis.ps1"
. "$PSScriptRoot/Get-Ps1AnalysisCache.ps1"
. "$PSScriptRoot/Import-Ps1Analyzer.ps1"
