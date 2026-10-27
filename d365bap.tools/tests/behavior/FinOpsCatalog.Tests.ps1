BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name FinOpsBehaviorFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/FinOpsVersionCache.ps1')
		. (Join-Path $Root 'functions/Get-PpacFinOpsVersion.ps1')
		. (Join-Path $Root 'functions/Get-PpacFinOpsBuild.ps1')
		function Test-PSFFunctionInterrupt { $false }
		function Get-DevToolsAuthContext {
			param($EnvironmentId)
			[pscustomobject]@{ Env = @{ PpacEnvUri = 'https://example.invalid' }; Token = 'fixture' }
		}
		function Write-FinOpsVersionCache { param($Versions, $Builds) }
		$script:exportCalls = @()
		function Export-Excel {
			param([Parameter(ValueFromPipeline)] $InputObject, [string] $WorksheetName, [string[]] $NoNumberConversion)
			process {
				$script:exportCalls += [pscustomobject]@{ InputObject = $InputObject; WorksheetName = $WorksheetName; NoNumberConversion = $NoNumberConversion }
			}
		}
		function Invoke-RestMethod {
			param($Method, $Uri, $Headers)
			if ($Uri -like '*finopsversions*') {
				@(
					[pscustomobject]@{ appVersion = '10.0.50'; appBuild = '7.0.7500'; platVersion = '7.0.50'; platBuild = '7.0.7500' }
					[pscustomobject]@{ appVersion = '10.0.49'; appBuild = '7.0.7400'; platVersion = '7.0.49'; platBuild = '7.0.7400' }
				)
			}
			elseif ($Uri -like '*finopsbuilds?version=7-0-7500*') {
				@('7.0.7500.10', '7.0.7500.2')
			}
			else { throw "Unexpected catalog request: $Uri" }
		}
		Export-ModuleMember -Function Get-PpacFinOpsVersion, Get-PpacFinOpsBuild
	}
	Import-Module $fixture -Force
}

Describe 'FinOps catalog user behavior' {
	It 'sorts tracks and selects the newest version with the expected output properties' {
		$versions = @(FinOpsBehaviorFixture\Get-PpacFinOpsVersion)
		$versions.AppVersion | Should -Be @('10.0.49', '10.0.50')
		$latest = FinOpsBehaviorFixture\Get-PpacFinOpsVersion -Latest
		$latest.AppVersion | Should -Be '10.0.50'
		$latest.AppBuild | Should -Be '7.0.7500'
		$latest.Track | Should -Be '7.0.7500'
	}

	It 'uses a piped version to select the latest build on that track' {
		$latest = FinOpsBehaviorFixture\Get-PpacFinOpsVersion -Latest | FinOpsBehaviorFixture\Get-PpacFinOpsBuild -Latest
		$latest.AppVersion | Should -Be '10.0.50'
		$latest.AppBuild | Should -Be '7.0.7500'
		$latest.Build | Should -Be '7.0.7500.10'
	}

	It 'exports version fields without converting them into numbers' {
		$output = @(FinOpsBehaviorFixture\Get-PpacFinOpsVersion -Latest -AsExcelOutput)
		$output.Count | Should -Be 0
		$exports = @(& (Get-Module FinOpsBehaviorFixture) { $script:exportCalls })
		$exports.Count | Should -Be 1
		$exports[0].WorksheetName | Should -Be 'Get-PpacFinOpsVersion'
		$exports[0].InputObject.AppVersion | Should -Be '10.0.50'
		$exports[0].NoNumberConversion | Should -Be @('AppVersion', 'AppBuild', 'Track', 'PlatVersion', 'PlatBuild')
	}
}
