BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name UnifiedEnvironmentFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		Import-Module PSFramework -ErrorAction Stop
		. (Join-Path $Root 'internal/functions/Test-Guid.ps1')
		. (Join-Path $Root 'functions/Get-UnifiedEnvironment.ps1')

		$script:propertyCalls = @()

		$script:envs = @(
			[pscustomobject]@{
				PpacEnvId             = '1287d8af-e9bc-e5a5-9ee6-3687e4c09f5b'
				PpacEnvName           = 'Features-Test-10.0.49'
				PpacEnvUri            = 'https://es-features-test-49.crm4.dynamics.com'
				FinOpsMetadataEnvType = 'Internal'
				Properties            = [pscustomobject]@{
					states = [pscustomobject]@{ runtime = [pscustomobject]@{ id = 'Normal' } }
				}
			}
			[pscustomobject]@{
				PpacEnvId             = '46874ac1-aaa0-e949-8d38-42caa04ecc5e'
				PpacEnvName           = 'Features-Uat-10.0.47'
				PpacEnvUri            = 'https://features-uat-47.crm4.dynamics.com'
				FinOpsMetadataEnvType = 'Internal'
				Properties            = [pscustomobject]@{
					states = [pscustomobject]@{ runtime = [pscustomobject]@{ id = 'Normal' } }
				}
			}
			[pscustomobject]@{
				PpacEnvId             = '2c97ad60-6c88-4f0e-a8b1-6fb3f0f3f0aa'
				PpacEnvName           = 'es-ude-motz-01'
				PpacEnvUri            = 'https://es-ude-motz-01.crm4.dynamics.com'
				FinOpsMetadataEnvType = 'Internal'
				Properties            = [pscustomobject]@{
					states = [pscustomobject]@{ runtime = [pscustomobject]@{ id = 'Normal' } }
				}
			}
			[pscustomobject]@{
				PpacEnvId             = '9a9cbb8a-3b0d-4a8d-9a2c-0f8b0b8e9c11'
				PpacEnvName           = 'linked-env-01'
				PpacEnvUri            = 'https://linked-env-01.crm4.dynamics.com'
				FinOpsMetadataEnvType = 'Linked'
				Properties            = [pscustomobject]@{
					states = [pscustomobject]@{ runtime = [pscustomobject]@{ id = 'Normal' } }
				}
			}
		)

		function Get-BapEnvironment {
			param($EnvironmentId, [switch] $FscmEnabled)

			$script:envs
		}

		function Get-BapAccessToken {
			param([switch] $PowerPlatform, $ResourceUrl)

			$objSecureToken = [System.Security.SecureString]::new()

			foreach ($itemChar in 'fixture-token'.ToCharArray()) {
				$objSecureToken.AppendChar($itemChar)
			}

			$objSecureToken
		}

		function Get-FinOpsEnvironmentProperty {
			param($EnvironmentId, $Token, $TimeoutSeconds)

			$script:propertyCalls += @($EnvironmentId)

			$hashResult = @{}

			foreach ($itemId in @($EnvironmentId)) {
				$hashResult[$itemId] = switch ($itemId) {
					'1287d8af-e9bc-e5a5-9ee6-3687e4c09f5b' {
						[pscustomobject]@{ deploymentType = 'UnifiedSandbox'; applicationVersion = '10.0.2790.83'; platformVersion = '7.0.8199.55' }
					}
					'46874ac1-aaa0-e949-8d38-42caa04ecc5e' {
						[pscustomobject]@{ deploymentType = 'UnifiedSandbox'; applicationVersion = '10.0.2790.83'; platformVersion = '7.0.8199.55' }
					}
					'2c97ad60-6c88-4f0e-a8b1-6fb3f0f3f0aa' {
						[pscustomobject]@{ deploymentType = 'UnifiedDeveloper'; applicationVersion = '10.0.2790.93'; platformVersion = '7.0.8199.60' }
					}
					default { $null }
				}
			}

			$hashResult
		}

		function Resolve-FinOpsVersionFromCache {
			param($Build)

			if ("$Build" -like '10.0.2790*') {
				return @{
					AppVersion  = '10.0.49'
					AppBuild    = '10.0.2790'
					PlatVersion = 'PU73'
					PlatBuild   = '7.0.8199'
				}
			}

			$null
		}

		function Write-PSFMessage { param($Level, $Message, $Exception) }
		function Write-PSFHostColor { param($String) }
		function Write-FinOpsVersionCache { param($Versions) }

		$script:exportCalls = @()

		function Export-Excel {
			param([Parameter(ValueFromPipeline)] $InputObject, [string] $WorksheetName, [string[]] $NoNumberConversion)

			process {
				$script:exportCalls += [pscustomobject]@{
					InputObject        = $InputObject
					WorksheetName      = $WorksheetName
					NoNumberConversion = $NoNumberConversion
				}
			}
		}

		Export-ModuleMember -Function Get-UnifiedEnvironment
	}
	Import-Module $fixture -Force
}

Describe 'Get-UnifiedEnvironment environment types' {
	It 'labels a unified sandbox environment as USE' {
		$envObj = UnifiedEnvironmentFixture\Get-UnifiedEnvironment -EnvironmentId 'Features-Test-10.0.49'

		$envObj.EnvType | Should -Be 'USE'
		$envObj.PpacProvType | Should -Be 'Sandbox'
	}

	It 'labels a unified developer environment as UDE' {
		$envObj = UnifiedEnvironmentFixture\Get-UnifiedEnvironment -EnvironmentId 'es-ude-motz-01'

		$envObj.EnvType | Should -Be 'UDE'
		$envObj.PpacProvType | Should -Be 'OnlineDev'
	}

	It 'returns only USE environments with -UseOnly' {
		$colEnv = @(UnifiedEnvironmentFixture\Get-UnifiedEnvironment -UseOnly)

		$colEnv.Count | Should -Be 2
		@($colEnv | Where-Object EnvType -ne 'USE').Count | Should -Be 0
		@($colEnv | Where-Object PpacEnvName -like 'Features-*').Count | Should -Be 2
	}

	It 'returns only UDE environments with -UdeOnly' {
		$colEnv = @(UnifiedEnvironmentFixture\Get-UnifiedEnvironment -UdeOnly)

		$colEnv.Count | Should -Be 1
		$colEnv[0].PpacEnvName | Should -Be 'es-ude-motz-01'
	}
}

Describe 'Get-UnifiedEnvironment version details' {
	It 'maps the cached catalog onto the version properties' {
		$envObj = UnifiedEnvironmentFixture\Get-UnifiedEnvironment -EnvironmentId 'es-ude-motz-01'

		$envObj.AppVersion | Should -Be '10.0.49'
		$envObj.AppBuild | Should -Be '10.0.2790'
		$envObj.Track | Should -Be '10.0.2790'
		$envObj.Build | Should -Be '10.0.2790.93'
		$envObj.PlatVersion | Should -Be 'PU73'
		$envObj.PlatBuild | Should -Be '7.0.8199'
		$envObj.PlatformVersion | Should -Be '7.0.8199.60'
	}

	It 'skips the property lookup with -SkipVersionDetails' {
		& (Get-Module UnifiedEnvironmentFixture) { $script:propertyCalls = @() }

		$colEnv = @(UnifiedEnvironmentFixture\Get-UnifiedEnvironment -SkipVersionDetails)
		$calls = & (Get-Module UnifiedEnvironmentFixture) { $script:propertyCalls }

		$colEnv.Count | Should -Be 3
		$calls.Count | Should -Be 0
		$colEnv[0].PSObject.Properties.Name | Should -Not -Contain 'AppVersion'
	}
}

Describe 'Get-UnifiedEnvironment environment matching' {
	It 'matches a wildcard environment name' {
		$colEnv = @(UnifiedEnvironmentFixture\Get-UnifiedEnvironment -EnvironmentId 'Features-*')

		$colEnv.Count | Should -Be 2
	}

	It 'matches an environment GUID' {
		$envObj = UnifiedEnvironmentFixture\Get-UnifiedEnvironment -EnvironmentId '2c97ad60-6c88-4f0e-a8b1-6fb3f0f3f0aa'

		$envObj.PpacEnvName | Should -Be 'es-ude-motz-01'
	}

	It 'excludes environments that are not unified' {
		$colEnv = @(UnifiedEnvironmentFixture\Get-UnifiedEnvironment)

		@($colEnv | Where-Object PpacEnvName -eq 'linked-env-01').Count | Should -Be 0
	}
}

Describe 'Get-UnifiedEnvironment Excel output' {
	It 'exports every environment to the command worksheet' {
		& (Get-Module UnifiedEnvironmentFixture) { $script:exportCalls = @() }

		$null = UnifiedEnvironmentFixture\Get-UnifiedEnvironment -AsExcelOutput
		$calls = @(& (Get-Module UnifiedEnvironmentFixture) { $script:exportCalls })

		$calls.Count | Should -Be 3
		@($calls | Where-Object WorksheetName -ne 'Get-UnifiedEnvironment').Count | Should -Be 0
		@($calls | Where-Object { $_.InputObject.EnvType -eq 'USE' }).Count | Should -Be 2
		$calls[0].NoNumberConversion | Should -Contain 'AppVersion'
	}
}
