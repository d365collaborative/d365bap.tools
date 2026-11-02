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
				$tmpDiagnostics.AddRange(@(Get-Ps1CommentDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1HelpDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1ParameterContractDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1ParameterLayoutDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1StandardOutputDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1AddMemberDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1AccessTokenDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1EnvironmentLookupDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1VariableNamingDiagnostic -Analysis $analysis `
							-Worker $Analyzer.Worker))
				$tmpDiagnostics.AddRange(@(Get-Ps1ShouldProcessDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1OutputTypeDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1FunctionInterruptDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1ReturnValueDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1ObjectArrayCastDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1ValidationAttributeOnMandatoryDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1WildcardParameterAsFilterDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1OrderedPSCustomObjectDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1OutNullDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1StandardExcelExportDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1LoopAppendDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1OneParameterPerLineDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1NotEqualNullDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1DirectParameterCheckDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1ReturnAfterStopDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1PipelineContinuationDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1ComplexArrayElementDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1SelectObjectPropertyDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1MultilineSelectObjectPropertyDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1AliasDiagnostic -Analysis $analysis `
							-Worker $Analyzer.Worker))
				$tmpDiagnostics.AddRange(@(Get-Ps1CentralApiVersionDiagnostic -Analysis $analysis))
				$tmpDiagnostics.AddRange(@(Get-Ps1FormattedUrlDiagnostic -Analysis $analysis))
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

. "$PSScriptRoot/Get-Ps1CommentDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1HelpDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ParameterContractDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ParameterLayoutDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1StandardOutputDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1AddMemberDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1AccessTokenDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1EnvironmentLookupDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1VariableNamingDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ShouldProcessDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1OutputTypeDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1FunctionInterruptDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ReturnValueDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ObjectArrayCastDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ValidationAttributeOnMandatoryDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1WildcardParameterAsFilterDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1OrderedPSCustomObjectDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1OutNullDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1StandardExcelExportDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1LoopAppendDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1OneParameterPerLineDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1CentralApiVersionDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1FormattedUrlDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1NotEqualNullDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1DirectStringCheckDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1HeadersVariableDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ModuleSplattingDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1EmptyLineAfterContinuationDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1DirectParameterCheckDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ReturnAfterStopDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1PipelineContinuationDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1ComplexArrayElementDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1SelectObjectPropertyDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1MultilineSelectObjectPropertyDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1AliasDiagnostic.ps1"
. "$PSScriptRoot/Get-Ps1AliasConfiguration.ps1"
. "$PSScriptRoot/Resolve-Ps1AliasCommand.ps1"
. "$PSScriptRoot/Get-Ps1CommentGroup.ps1"
. "$PSScriptRoot/Get-Ps1HelpSection.ps1"
. "$PSScriptRoot/Get-Ps1Analysis.ps1"
