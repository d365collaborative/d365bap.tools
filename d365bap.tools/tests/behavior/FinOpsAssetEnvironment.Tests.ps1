BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name FinOpsAssetEnvFixture -ArgumentList $sourceRoot, (Join-Path $TestDrive 'finopsversions.json') -ScriptBlock {
		param($Root, $CachePath)
		. (Join-Path $Root 'internal/functions/FinOpsVersionCache.ps1')
		. (Join-Path $Root 'functions/Get-PpacFinOpsAsset.ps1')
		function Test-PSFFunctionInterrupt { $false }
		$script:unifiedCalls = @()
		$script:restCalls = @()
		function Get-DevToolsAuthContext {
			param($EnvironmentId)
			@{ Env = [pscustomobject]@{ PpacEnvUri = 'https://example.invalid'; PpacEnvName = 'es-ude-motz-01' }; Token = 'fixture' }
		}
		function Get-Environment {
			param($EnvironmentId, [switch] $Unified, [switch] $VersionDetails)
			if (-not $Unified -or -not $VersionDetails) { throw 'Provisioning lookup requires unified version details.' }
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
		$script:cachePath = $CachePath
		function Get-FinOpsVersionCachePath { $script:cachePath }
		function Get-FinOpsVersionCacheStamp { @{ TenantId = 'fixture'; AccountId = 'fixture' } }
		$script:failPlatformLookup = $false
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
			if ($script:failPlatformLookup -and $Uri -like '*finopsplatbuild?version=*') { throw 'Platform service unavailable' }
			if ($Uri -like '*finopsplatbuild?version=10-0-2790-93') { return '7.0.8199.60' }
			if ($Uri -like '*finopsplatbuild?version=10-0-2790-105') { return '7.0.8199.70' }
			if ($Uri -like '*/vhd?version=10-0-49') {
				return @('https://example.invalid/finops.vhd.001?sig=abc', 'https://example.invalid/finops.vhd.002?sig=abc')
			}
			if ($Uri -like '*finopsversions*') {
				return @(
					[pscustomobject]@{ appVersion = '10.0.49'; appBuild = '10.0.2790'; platVersion = 'PU73'; platBuild = '7.0.8199' }
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
	BeforeEach {
		$cachePath = Join-Path $TestDrive 'finopsversions.json'
		if (Test-Path -LiteralPath $cachePath) { Remove-Item -LiteralPath $cachePath }
	}

	It 'filters assets by kind <Kind> without adding VHD for the wildcard' -ForEach @(
		@{ Kind = '*'; Count = 9 }
		@{ Kind = 'NuGet'; Count = 5 }
		@{ Kind = 'DeveloperFile'; Count = 4 }
		@{ Kind = 'Vhd'; Count = 2 }
	) {
		param($Kind, $Count)
		$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -Build '10.0.2790.93' -Kind $Kind)
		$assets.Count | Should -Be $Count
		@($assets | Where-Object { $_.Kind -notlike $Kind }).Count | Should -Be 0
	}

	It 'includes VHD parts when all assets are explicitly requested and places Build after Uri' {
		$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -Build '10.0.2790.93' -Asset '*')
		$assets.Count | Should -Be 11
		$vhd = @($assets | Where-Object Asset -eq Vhd)
		$vhd.Count | Should -Be 2
		$propertyNames = @($vhd[0].PSObject.Properties.Name)
		$propertyNames.IndexOf('Build') | Should -Be ($propertyNames.IndexOf('Uri') + 1)
	}

	It 'keeps asset URLs available with cached metadata when platform lookup fails' {
		& (Get-Module FinOpsAssetEnvFixture) { $script:failPlatformLookup = $true }
		try {
			$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -Build '10.0.2790.93' -Asset Application1)
		}
		finally {
			& (Get-Module FinOpsAssetEnvFixture) { $script:failPlatformLookup = $false }
		}
		$assets.Count | Should -Be 1
		$assets[0].Uri | Should -Be 'https://example.invalid/fixture-package.10.0.2790.93.nupkg?sig=abc'
		$assets[0].PlatBuild | Should -Be '7.0.8199'
	}

	It 'uses the environment provisioned build when only EnvironmentId is supplied' {
		& (Get-Module FinOpsAssetEnvFixture) { $script:restCalls = @(); $script:unifiedCalls = @() }
		$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -EnvironmentId 'es-ude-motz-01')
		$assets.Count | Should -BeGreaterThan 0
		$uniqueBuilds = @($assets | Select-Object -ExpandProperty Build -Unique)
		$uniqueBuilds.Count | Should -Be 1
		$uniqueBuilds[0] | Should -Be '10.0.2790.93'
		@($assets | Select-Object -ExpandProperty PlatBuild -Unique) | Should -Be '7.0.8199.60'
		$assets[0].PlatVersion | Should -Be 'PU73'
		$propertyNames = @($assets[0].PSObject.Properties.Name)
		$propertyNames.IndexOf('Build') | Should -Be ($propertyNames.IndexOf('Uri') + 1)
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
		@($assets | Select-Object -ExpandProperty PlatBuild -Unique) | Should -Be '7.0.8199.70'
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

	It 'persists separate platform revisions and reuses the exact cached build when the service fails' {
		$null = FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -Build '10.0.2790.93' -Asset Application1
		$null = FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -Build '10.0.2790.105' -Asset Application1
		$cache = Get-Content -LiteralPath (Join-Path $TestDrive 'finopsversions.json') -Raw | ConvertFrom-Json
		$cache.platforms.'10.0.2790.93' | Should -Be '7.0.8199.60'
		$cache.platforms.'10.0.2790.105' | Should -Be '7.0.8199.70'
		$cache.versions[0].platBuild | Should -Be '7.0.8199'
		& (Get-Module FinOpsAssetEnvFixture) { $script:failPlatformLookup = $true }
		try {
			$asset = FinOpsAssetEnvFixture\Get-PpacFinOpsAsset -Build '10.0.2790.93' -Asset Application1
			$asset.PlatBuild | Should -Be '7.0.8199.60'
			$versions = & (Get-Module FinOpsAssetEnvFixture) {
				Resolve-FinOpsVersionFromCache -Build '10-0-2790-105'
				Resolve-FinOpsVersionFromCache -Build '10.0.2790'
			}
			$versions[0].PlatBuild | Should -Be '7.0.8199.70'
			$versions[1].PlatBuild | Should -Be '7.0.8199'
		}
		finally {
			& (Get-Module FinOpsAssetEnvFixture) { $script:failPlatformLookup = $false }
		}
	}

	It 'resolves the newest build when no EnvironmentId, Build or AppVersion is supplied' {
		& (Get-Module FinOpsAssetEnvFixture) { $script:restCalls = @(); $script:unifiedCalls = @() }
		$assets = @(FinOpsAssetEnvFixture\Get-PpacFinOpsAsset)
		$uniqueBuilds = @($assets | Select-Object -ExpandProperty Build -Unique)
		$uniqueBuilds.Count | Should -Be 1
		$uniqueBuilds[0] | Should -Be '10.0.2790.105'
	}
}
