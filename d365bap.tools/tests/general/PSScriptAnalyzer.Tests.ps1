[CmdletBinding()]
Param (
	[switch]
	$SkipTest,

	[string[]]
	$CommandPath = @("$global:testroot\..\functions", "$global:testroot\..\internal\functions")
)

BeforeDiscovery {
	if ($SkipTest) { return }

	$global:__pester_data.ScriptAnalyzer = New-Object System.Collections.ArrayList

	$commandFiles = $CommandPath | ForEach-Object {
		Get-ChildItem -LiteralPath $_ -Recurse -ErrorAction Stop | Where-Object Name -like "*.ps1"
	} | ForEach-Object {
		@{
			BaseName = $_.BaseName
			FullName = $_.FullName
		}
	}
}

Describe 'Invoking the shared analyzer against commandbase' {
	BeforeAll {
		. (Join-Path $PSScriptRoot '../../../build/ps1-lint/internal/Invoke-Ps1Analysis.ps1')
		$analyzer = New-Ps1Analyzer
	}

	Context "Analyzing <BaseName>" -ForEach $commandFiles {
		BeforeAll {
			$analysisResult = Invoke-Ps1Analysis -Path $FullName -Analyzer $analyzer -SkipCustomRules
		}

		It 'Should pass the shared analyzer policy' {
			foreach ($diagnostic in @($analysisResult.Diagnostics)) {
				"$($diagnostic.RuleName): $($diagnostic.Severity) at Line $($diagnostic.Line) Column $($diagnostic.Column) with '$($diagnostic.Extent)'"
				$null = $global:__pester_data.ScriptAnalyzer.Add($diagnostic)
			}

			$analysisResult.Failed | Should -BeFalse
		}
	}
}
