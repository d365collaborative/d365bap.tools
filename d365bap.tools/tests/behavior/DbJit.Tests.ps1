BeforeDiscovery {
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name DbJitBehavior -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		Import-Module PSFramework -ErrorAction Stop
		. (Join-Path $Root 'internal/functions/Get-BapAccessToken.ps1')
		. (Join-Path $Root 'internal/functions/Get-Environment.ps1')
		. (Join-Path $Root 'functions/Get-UdeDbJit.ps1')
		Export-ModuleMember -Function Get-UdeDbJit
	}
	Import-Module $fixture -Force
}

Describe 'In-memory database JIT requests' {
	InModuleScope DbJitBehavior {
		BeforeEach {
			Mock Test-PSFFunctionInterrupt { $false }
			Mock Write-PSFMessage {}
			Mock Start-Sleep {}
			Mock Get-BapAccessToken {
				$token = [Security.SecureString]::new()
				$token.AppendChar('x')
				$token
			}
			Mock Get-Environment {
				[pscustomobject]@{
					PpacEnvId             = 'fixture-id'
					PpacEnvUri            = 'https://fixture.crm4.dynamics.com/'
					FinOpsMetadataEnvType = 'Internal'
				}
			}
			Mock Invoke-RestMethod { '203.0.113.7' } -ParameterFilter { $Uri -eq 'https://icanhazip.com' }
			Mock Invoke-RestMethod {
				param($Body)
				$script:payload = $Body | ConvertFrom-Json
				[pscustomobject]@{
					servername       = 'fixture.database.windows.net'
					databasename     = 'fixture-db'
					sqljitusername   = 'fixture-reader'
					sqljitpassword   = 'fixture-password'
					sqljitexpiration = [DateTimeOffset]::UtcNow.AddHours(1).ToString('o')
					sqljitrole       = $payload.sqljitrole
				}
			} -ParameterFilter { $Method -eq 'Post' }
		}

		It 'requests Reader access, discovers the public IP, and normalizes the expiration' {
			$result = Get-UdeDbJit -EnvironmentId 'fixture-env'
			$result.Server | Should -Be 'fixture.database.windows.net'
			$result.Database | Should -Be 'fixture-db'
			$result.Password | Should -Be 'fixture-password'
			$result.EnvironmentId | Should -Be 'fixture-id'
			$result.Expiration | Should -BeOfType ([datetime])
			$result.Expiration.Kind | Should -Be ([DateTimeKind]::Utc)
			$payload.sqljitrole | Should -Be 'Reader'
			$payload.sqljitclientipaddress | Should -Be '203.0.113.7'
			$payload.sqljitreason | Should -Be 'Administrative access via d365bap.tools'
			Should -Invoke Get-BapAccessToken -Times 1 -Exactly -ParameterFilter { $ResourceUrl -eq 'https://fixture.crm4.dynamics.com/' }
			Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Method -eq 'Post' -and $Uri -eq 'https://fixture.crm4.dynamics.com/api/data/v9.2/msprov_getfinopssqljitaccessasync' }
			Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 60 }
		}

		It 'honors explicit Writer access, CIDR, reason and a zero propagation wait' {
			Get-UdeDbJit -EnvironmentId 'fixture-env' -Role Writer -WhitelistIp '203.0.113.0/24' -Reason 'Approved migration' -WaitSeconds 0 > $null
			$payload.sqljitrole | Should -Be 'Writer'
			$payload.sqljitclientipaddress | Should -Be '203.0.113.0/24'
			$payload.sqljitreason | Should -Be 'Approved migration'
			Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -eq 'https://icanhazip.com' }
			Should -Invoke Start-Sleep -Times 0 -Exactly
		}

		It 'rejects ambiguous environment matches before requesting access' {
			Mock Get-Environment {
				@(
					[pscustomobject]@{ PpacEnvId = 'one'; FinOpsMetadataEnvType = 'Internal' }
					[pscustomobject]@{ PpacEnvId = 'two'; FinOpsMetadataEnvType = 'Internal' }
				)
			}
			{ Get-UdeDbJit -EnvironmentId 'fixture*' } | Should -Throw '*exactly one*found 2*'
			Should -Invoke Invoke-RestMethod -Times 0 -Exactly
			Should -Invoke Get-BapAccessToken -Times 0 -Exactly
		}

		It 'rejects missing or non-unified environments before requesting access' {
			Mock Get-Environment { [pscustomobject]@{ FinOpsMetadataEnvType = 'Linked' } }
			{ Get-UdeDbJit -EnvironmentId 'fixture' } | Should -Throw '*exactly one*found 0*'
			Should -Invoke Invoke-RestMethod -Times 0 -Exactly
		}

		It 'rejects an invalid public IP before requesting access' {
			Mock Invoke-RestMethod { 'invalid-address' } -ParameterFilter { $Uri -eq 'https://icanhazip.com' }
			{ Get-UdeDbJit -EnvironmentId 'fixture' } | Should -Throw '*public IP*'
			Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Method -eq 'Post' }
		}
	}
}
