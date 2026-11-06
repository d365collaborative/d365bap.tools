BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name FinOpsBehaviorFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/FinOpsVersionCache.ps1')
		. (Join-Path $Root 'functions/Get-PpacFinOpsVersion.ps1')
		. (Join-Path $Root 'functions/Get-PpacFinOpsBuild.ps1')
		. (Join-Path $Root 'functions/Get-PpacFinOpsAsset.ps1')
		function Test-PSFFunctionInterrupt { $false }
		function Get-DevToolsAuthContext {
			param($EnvironmentId)
			$script:authEnvironment = $EnvironmentId
			[pscustomobject]@{ Env = [pscustomobject]@{ PpacEnvUri = 'https://example.invalid'; PpacProvApp = '7.0.7500.2' }; Token = 'fixture' }
		}
		function Write-FinOpsVersionCache { param($Versions, $Builds, $Platforms) }
		function Resolve-FinOpsVersionFromCache { param($Build) $null }
		$script:exportCalls = @()
		$script:requests = @()
		function Export-Excel {
			param([Parameter(ValueFromPipeline)] $InputObject, [string] $WorksheetName, [string[]] $NoNumberConversion)
			process {
				$script:exportCalls += [pscustomobject]@{ InputObject = $InputObject; WorksheetName = $WorksheetName; NoNumberConversion = $NoNumberConversion }
			}
		}
		function Invoke-RestMethod {
			param($Method, $Uri, $Headers)
			$script:requests += [pscustomobject]@{ Uri = $Uri; Headers = $Headers }
			if ($Uri -like '*finopsversions*') {
				@(
					[pscustomobject]@{ appVersion = '10.0.50'; appBuild = '7.0.7500'; platVersion = '7.0.50'; platBuild = '7.0.7500' }
					[pscustomobject]@{ appVersion = '10.0.49'; appBuild = '7.0.7400'; platVersion = '7.0.49'; platBuild = '7.0.7400' }
				)
			}
			elseif ($Uri -like '*finopsbuilds?version=7-0-7500*') {
				@('7.0.7500.10', '7.0.7500.2')
			}
			elseif ($Uri -like '*finopsbuilds?version=7-0-7400*') {
				@('7.0.7400.8', '7.0.7400.3')
			}
			elseif ($Uri -like '*nugetpackage?*') { 'https://example.invalid/package.zip' }
			elseif ($Uri -like '*finopsplatbuild?*') { '7.0.7500.1' }
			else { throw "Unexpected catalog request: $Uri" }
		}
		Export-ModuleMember -Function Get-PpacFinOpsVersion, Get-PpacFinOpsBuild, Get-PpacFinOpsAsset
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

	Context 'asset authentication and build selection' {
		BeforeEach {
			& (Get-Module FinOpsBehaviorFixture) { $script:authEnvironment = $null; $script:requests = @() }
		}

		It 'uses the requested environment for a different explicit build' {
			$asset = FinOpsBehaviorFixture\Get-PpacFinOpsAsset -EnvironmentId 'chosen-env' -Build '7.0.7400.3' -Asset Platform
			$asset.Build | Should -Be '7.0.7400.3'
			$state = & (Get-Module FinOpsBehaviorFixture) { @{ Environment = $script:authEnvironment; Requests = $script:requests } }
			$state.Environment | Should -Be 'chosen-env'
			@($state.Requests | Where-Object { $_.Headers.Dataverseenvironmenturi -ne 'https://example.invalid' -or $_.Headers.Authorization -ne 'Bearer fixture' }).Count | Should -Be 0
			@($state.Requests | Where-Object { $_.Uri -like '*nugetpackage?*version=7-0-7400-3' }).Count | Should -Be 1
		}

		It 'uses the provisioned build when only the environment is given' {
			$asset = FinOpsBehaviorFixture\Get-PpacFinOpsAsset -EnvironmentId 'chosen-env' -Asset Platform
			$asset.Build | Should -Be '7.0.7500.2'
			& (Get-Module FinOpsBehaviorFixture) { $script:authEnvironment } | Should -Be 'chosen-env'
		}

		It 'uses the environment with an explicit track selector' -ForEach @(
			@{ Selector = @{ Build = '7.0.7400' } }
			@{ Selector = @{ AppVersion = '10.0.49' } }
		) {
			param($Selector)
			$asset = FinOpsBehaviorFixture\Get-PpacFinOpsAsset -EnvironmentId 'chosen-env' -Asset Platform @Selector
			$asset.Build | Should -Be '7.0.7400.8'
			& (Get-Module FinOpsBehaviorFixture) { $script:authEnvironment } | Should -Be 'chosen-env'
		}

		It 'uses a piped build with the requested environment' {
			$asset = [pscustomobject]@{ Build = '7.0.7400.3' } | FinOpsBehaviorFixture\Get-PpacFinOpsAsset -EnvironmentId 'chosen-env' -Asset Platform
			$asset.Build | Should -Be '7.0.7400.3'
			& (Get-Module FinOpsBehaviorFixture) { $script:authEnvironment } | Should -Be 'chosen-env'
		}

		It 'retains automatic authentication when no environment is provided' {
			$asset = FinOpsBehaviorFixture\Get-PpacFinOpsAsset -Build '7.0.7400.3' -Asset Platform
			$asset.Build | Should -Be '7.0.7400.3'
			& (Get-Module FinOpsBehaviorFixture) { $script:authEnvironment } | Should -BeNullOrEmpty
		}
	}
}
