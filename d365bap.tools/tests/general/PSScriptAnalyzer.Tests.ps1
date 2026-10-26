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
		Get-ChildItem -Path $_ -Recurse | Where-Object Name -like "*.ps1"
	} | ForEach-Object {
		@{
			BaseName = $_.BaseName
			FullName = $_.FullName
		}
	}

	$ruleNames = @(Get-ScriptAnalyzerRule | ForEach-Object { $_.RuleName })
	if ($ruleNames.Count -eq 0) { throw 'PSScriptAnalyzer returned no rules; cannot validate scripts.' }
	foreach ($commandFile in $commandFiles) { $commandFile.RuleNames = $ruleNames }
}

Describe 'Invoking PSScriptAnalyzer against commandbase' {

	Context "Analyzing <BaseName>" -ForEach $commandFiles {
		BeforeAll {
			$analysis = Invoke-ScriptAnalyzer -Path $FullName -ExcludeRule PSAvoidTrailingWhitespace, PSShouldProcess
		}

		It 'Should pass the discovered analyzer rules' {
			$diagnostics = foreach ($ruleName in $RuleNames) {
				$analysis | Where-Object RuleName -EQ $ruleName | ForEach-Object {
					"$($_.RuleName): $($_.Severity) at Line $($_.Line) Column $($_.Column) with '$($_.Extent)'"
					$null = $global:__pester_data.ScriptAnalyzer.Add($_)
				}
			}
			$diagnostics | Should -BeNullOrEmpty
		}
	}
}
