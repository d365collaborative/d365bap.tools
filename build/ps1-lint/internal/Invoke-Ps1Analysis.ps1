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
	$targetVersion = [version] $hashSettings.PSScriptAnalyzerVersion
	$colAvailable = @(Get-Module -Name PSScriptAnalyzer `
			-ListAvailable `
			-ErrorAction SilentlyContinue |
		Where-Object { $_.Version -eq $targetVersion })

	if ($colAvailable.Count -eq 0) {
		throw "PSScriptAnalyzer $($hashSettings.PSScriptAnalyzerVersion) is not installed. Run build/ps1-lint/setup/Run.ps1."
	}

	Import-Module PSScriptAnalyzer `
		-RequiredVersion $hashSettings.PSScriptAnalyzerVersion `
		-ErrorAction Stop

	[pscustomobject]@{
		Settings = $hashSettings
		Worker   = Get-Ps1AnalysisWorker
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
		[pscustomobject]@{ Id = 'Get-Ps1StandardOutputDiagnostic'; Script = 'Get-Ps1StandardOutputDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1AddMemberDiagnostic'; Script = 'Get-Ps1AddMemberDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1AccessTokenDiagnostic'; Script = 'Get-Ps1AccessTokenDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1EnvironmentLookupDiagnostic'; Script = 'Get-Ps1EnvironmentLookupDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1VariableNamingDiagnostic'; Script = 'Get-Ps1VariableNamingDiagnostic.ps1'; NeedsWorker = $true }
		[pscustomobject]@{ Id = 'Get-Ps1ShouldProcessDiagnostic'; Script = 'Get-Ps1ShouldProcessDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OutputTypeDiagnostic'; Script = 'Get-Ps1OutputTypeDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1FunctionInterruptDiagnostic'; Script = 'Get-Ps1FunctionInterruptDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ReturnValueDiagnostic'; Script = 'Get-Ps1ReturnValueDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ObjectArrayCastDiagnostic'; Script = 'Get-Ps1ObjectArrayCastDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ValidationAttributeOnMandatoryDiagnostic'; Script = 'Get-Ps1ValidationAttributeOnMandatoryDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1WildcardParameterAsFilterDiagnostic'; Script = 'Get-Ps1WildcardParameterAsFilterDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OrderedPSCustomObjectDiagnostic'; Script = 'Get-Ps1OrderedPSCustomObjectDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OutNullDiagnostic'; Script = 'Get-Ps1OutNullDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1StandardExcelExportDiagnostic'; Script = 'Get-Ps1StandardExcelExportDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1LoopAppendDiagnostic'; Script = 'Get-Ps1LoopAppendDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1OneParameterPerLineDiagnostic'; Script = 'Get-Ps1OneParameterPerLineDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1NotEqualNullDiagnostic'; Script = 'Get-Ps1NotEqualNullDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1DirectParameterCheckDiagnostic'; Script = 'Get-Ps1DirectParameterCheckDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ReturnAfterStopDiagnostic'; Script = 'Get-Ps1ReturnAfterStopDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1PipelineContinuationDiagnostic'; Script = 'Get-Ps1PipelineContinuationDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ComplexArrayElementDiagnostic'; Script = 'Get-Ps1ComplexArrayElementDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1SelectObjectPropertyDiagnostic'; Script = 'Get-Ps1SelectObjectPropertyDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1MultilineSelectObjectPropertyDiagnostic'; Script = 'Get-Ps1MultilineSelectObjectPropertyDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1AliasDiagnostic'; Script = 'Get-Ps1AliasDiagnostic.ps1'; NeedsWorker = $true }
		[pscustomobject]@{ Id = 'Get-Ps1CentralApiVersionDiagnostic'; Script = 'Get-Ps1CentralApiVersionDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1FormattedUrlDiagnostic'; Script = 'Get-Ps1FormattedUrlDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1MultilineIfExpressionDiagnostic'; Script = 'Get-Ps1MultilineIfExpressionDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1MultilineIfConditionDiagnostic'; Script = 'Get-Ps1MultilineIfConditionDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1TernaryInObjectInitializationDiagnostic'; Script = 'Get-Ps1TernaryInObjectInitializationDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1DirectStringCheckDiagnostic'; Script = 'Get-Ps1DirectStringCheckDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1HeadersVariableDiagnostic'; Script = 'Get-Ps1HeadersVariableDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1ModuleSplattingDiagnostic'; Script = 'Get-Ps1ModuleSplattingDiagnostic.ps1'; NeedsWorker = $false }
		[pscustomobject]@{ Id = 'Get-Ps1EmptyLineAfterContinuationDiagnostic'; Script = 'Get-Ps1EmptyLineAfterContinuationDiagnostic.ps1'; NeedsWorker = $false }
	)
}

function Invoke-Ps1Analysis {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]] $Path,
		[Parameter(Mandatory = $true)]
		$Analyzer,
		# Full scans keep the historical built-in-only coverage. Custom rules
		# are adopted as files change, so their existing debt must not fail a
		# module-wide run.
		[switch] $SkipCustomRules
	)

	process {
		foreach ($itemPath in @($Path)) {
			$analysis = Get-Ps1Analysis -Path $itemPath
			$tmpParseDiagnostics = @(Get-Ps1ParseDiagnostic -Analysis $analysis)

			if ($tmpParseDiagnostics.Count -gt 0) {
				[pscustomobject]@{
					Path        = $itemPath
					Diagnostics = $tmpParseDiagnostics
					Failed      = $true
				}
				continue
			}

			$tmpDiagnostics = [System.Collections.Generic.List[object]]::new()
			$tmpBuiltIn = @(Invoke-ScriptAnalyzer -Path $itemPath `
					-Recurse `
					-Severity $Analyzer.Settings.Severity `
					-ExcludeRule $Analyzer.Settings.ExcludeRule `
					-ErrorAction Stop)
			if (($itemPath -replace '\\', '/') -match $Analyzer.Settings.ModulePathPattern) {
				$tmpBuiltIn = @($tmpBuiltIn | Where-Object RuleName -ne 'PSShouldProcess')
			}
			$tmpDiagnostics.AddRange($tmpBuiltIn)

			if (-not $SkipCustomRules) {
				foreach ($itemRule in Get-Ps1DiagnosticRule) {
					$tmpRule = @{ Analysis = $analysis }
					if ($itemRule.NeedsWorker) {
						$tmpRule.Worker = $Analyzer.Worker
					}
					$tmpDiagnostics.AddRange(@(& $itemRule.Id @tmpRule))
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
