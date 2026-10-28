BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name FinOpsAssetEnvFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/FinOpsVersionCache.ps1')
		. (Join-Path $Root 'functions/Get-PpacFinOpsAsset.ps1')
		function Test-PSFFunctionInterrupt { $false }
		$script:unifiedCalls = @()
		$script:restCalls = @()
		function Get-DevToolsAuthContext {
			param($EnvironmentId)
			# Mimics SkipVersionDetails: no PpacProvApp on purpose
			@{ Env = [pscustomobject]@{ PpacEnvUri = 'https://example.invalid'; PpacEnvName = 'es-ude-motz-01' }; Token = 'fixture' }
		}
		function Get-UnifiedEnvironment {
			param($EnvironmentId)
			$script:unifiedCalls += "$EnvironmentId"
			if ("$EnvironmentId" -eq 'missing-env') { return $null }
			if ("$EnvironmentId" -eq 'no-version-env') {
				return [pscustomobject]@{ PpacEnvName = 'no-version-env'; PpacEnvUri = 'https://example.invalid' }
			}
			[pscustomobject]@{
				PpacEnvName      = 'es-ude-motz-01'
				PpacEnvUri       = 'https://example.invalid'
				PpacProvApp      = '10.0.2790.93'
				PpacProvPlatform = '7.0.8199.60'
			}
		}
		function Write-FinOpsVersionCache { param($Versions, $Builds, $Platforms) }
		function Resolve-FinOpsVersionFromCache { param($Build) return $null }
		$script:exportCalls = @()
		function Export-Excel {
			param([Parameter(ValueFromPipeline)] $InputObject, [string] $WorksheetName, [string[]] $NoNumberConversion)
			process {
				$script:exportCalls += [pscustomobject]@{ InputObject = $InputObject; WorksheetName = $WorksheetName }
			}
		}
		function Invoke-RestMethod {
			param($Method, $Uri, $Headers)
			$script:restCalls += "$Uri"
			if ($Uri -like '*finopsversions*') {
				return @(
					[pscustomobject]@{ appVersion = '10.0.49'; appBuild = '10.0.2790'; platVersion = '7.0.8199'; platBuild = '7.0.8199' }
				)
			}
			if ($Uri -like '*finopsbuilds?version=10-0-2790*') {
				return @('10.0.2790.93', '10.0.2790.105')
			}
			if ($Uri -like '*nugetpackage*version=10-0-2790-93*') {
				return 'https://example.invalid/fixture-package.10.0.2790.93.nupkg?sig=abc'
			}
			if ($Uri -like '*nugetpackage*') {
				return 'https://example.invalid/fixture-package.10.0.2790.105.nupkg?sig=abc'
			}
			if ($Uri -like '*systemmetadata?version=10-0-2790-93*') {
				return 'https://example.invalid/PackagesLocalDirectory.zip?sig=abc'
			}
			if ($Uri -like '*finopsvsix22?version=10-0-2790-93*') {
				return 'https://example.invalid/Microsoft.Dynamics.Framework.Tools.Installer.17.0.vsix?sig=abc'
			}
			if ($Uri -like '*traceparser?version=10-0-2790-93*') {
				return 'https://example.invalid/TraceParser.msi?sig=abc'
			}
			if ($Uri -like '*crossreference?version=10-0-2790-93*') {
				return 'https://example.invalid/DYNAMICSXREFDB.bak?sig=abc'
			}
			if ($Uri -like '*/systemmetadata?version=*') { return 'https://example.invalid/PackagesLocalDirectory.zip?sig=newest' }
			if ($Uri -like '*/finopsvsix22?version=*') { return 'https://example.invalid/Microsoft.Dynamics.Framework.Tools.Installer.17.0.vsix?sig=newest' }
			if ($Uri -like '*/traceparser?version=*') { return 'https://example.invalid/TraceParser.msi?sig=newest' }
			if ($Uri -like '*/crossreference?version=*') { return 'https://example.invalid/DYNAMICSXREFDB.bak?sig=newest' }
			throw "Unexpected asset request: $Uri"
		}
		Export-ModuleMember -Function Get-PpacFinOpsAsset
	}
	Import-Module $fixture -Force
}

Describe 'Get-PpacFinOpsAsset parameter sets' {
	It 'exposes ByBuild as default and ByEnvironment with mandatory EnvironmentId' {
		$cmd = Get-Command FinOpsAssetEnvFixture\Get-PpacFinOpsAsset
		$cmd.ParameterSets.Name | Should -Contain 'ByBuild'
		$cmd.ParameterSets.Name | Should -Contain 'ByEnvironment'
		($cmd.Parameters['EnvironmentId'].ParameterSets.Keys) | Should -Be 'ByEnvironment'
		($cmd.Parameters['Build'].ParameterSets.Keys) | Should -Be 'ByBuild'
		($cmd.Parameters['AppVersion'].ParameterSets.Keys) | Should -Be 'ByBuild'
		$envParam = ($cmd.ParameterSets | Where-Object Name -eq 'ByEnvironment').Parameters | Where-Object Name -eq 'EnvironmentId'
		$envParam.IsMandatory | Should -Be $true
	}

	It 'rejects EnvironmentId combined with Build' {
		{ FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -EnvironmentId 'es-ude-motz-01' -Build '10.0.2790.105' -ErrorAction Stop } | Should -Throw
	}

	It 'rejects EnvironmentId combined with AppVersion' {
		{ FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -EnvironmentId 'es-ude-motz-01' -AppVersion '10.0.49' -ErrorAction Stop } | Should -Throw
	}
}

Describe 'Get-PpacFinOpsAsset environment build resolution' {
	It 'uses the environment provisioned build when only EnvironmentId is supplied' {
		& (Get-Module FinOpsAssetEnvFixture) { $script:restCalls = @(); $script:unifiedCalls = @() }
		$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -EnvironmentId 'es-ude-motz-01')
		$assets.Count | Should -BeGreaterThan 0
		$uniqueBuilds = @($assets | Select-Object -ExpandProperty Build -Unique)
		$uniqueBuilds.Count | Should -Be 1
		$uniqueBuilds[0] | Should -Be '10.0.2790.93'
		$calls = & (Get-Module FinOpsAssetEnvFixture) { $script:restCalls }
		($calls -join "`n") | Should -Match '10-0-2790-93'
		($calls -join "`n") | Should -Not -Match '10-0-2790-105'
	}

	It 'resolves an explicit Build without touching the environment lookup' {
		& (Get-Module FinOpsAssetEnvFixture) { $script:restCalls = @(); $script:unifiedCalls = @() }
		$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -Build '10.0.2790.105')
		$uniqueBuilds = @($assets | Select-Object -ExpandProperty Build -Unique)
		$uniqueBuilds.Count | Should -Be 1
		$uniqueBuilds[0] | Should -Be '10.0.2790.105'
		$unified = & (Get-Module FinOpsAssetEnvFixture) { $script:unifiedCalls }
		$unified.Count | Should -Be 0
	}

	It 'resolves a piped environment object via the ByEnvironment set' {
		& (Get-Module FinOpsAssetEnvFixture) { $script:restCalls = @(); $script:unifiedCalls = @() }
		$envObj = [pscustomobject]@{ PpacEnvId = 'es-ude-motz-01'; PpacEnvName = 'es-ude-motz-01' }
		$assets = @($envObj | FinOpsAssetEnvFixture\Get-PpacFinOpsAsset)
		$uniqueBuilds = @($assets | Select-Object -ExpandProperty Build -Unique)
		$uniqueBuilds.Count | Should -Be 1
		$uniqueBuilds[0] | Should -Be '10.0.2790.93'
	}

	It 'resolves the newest build when no EnvironmentId, Build or AppVersion is supplied' {
		& (Get-Module FinOpsAssetEnvFixture) { $script:restCalls = @(); $script:unifiedCalls = @() }
		$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset)
		$uniqueBuilds = @($assets | Select-Object -ExpandProperty Build -Unique)
		$uniqueBuilds.Count | Should -Be 1
		$uniqueBuilds[0] | Should -Be '10.0.2790.105'
	}
}
