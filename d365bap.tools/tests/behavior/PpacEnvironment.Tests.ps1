BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacEnvironmentBehaviorFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'functions/Get-PpacEnvironment.ps1')
		$script:BapApiVersions = @{ PowerPlatform = '2024-10-01' }
		function Get-BapAccessToken {
			param([switch] $PowerPlatform)
			if (-not $PowerPlatform) { throw 'Unexpected token audience.' }
			$objToken = [Security.SecureString]::new()
			$objToken.AppendChar('x')
			$objToken
		}
		function Get-BapEnvironment { throw 'Legacy discovery must not be used.' }
		function Invoke-BapSdkRequest {
			param($Resource, $Method, $Token, $RequestUrl)
			$null = $Resource, $Method, $Token
			$script:requests.Add($RequestUrl)
			$response = $script:responses.Dequeue()
			if ($response -is [Exception]) { throw $response }
			$response
		}
		Export-ModuleMember -Function Get-PpacEnvironment
	}
	Import-Module $fixture -Force
}

AfterAll {
	Remove-Module PpacEnvironmentBehaviorFixture
}

Describe 'Power Platform environment discovery' {
	BeforeEach {
		& (Get-Module PpacEnvironmentBehaviorFixture) {
			$script:requests = [Collections.Generic.List[string]]::new()
			$script:responses = [Collections.Generic.Queue[object]]::new()
		}
	}

	It 'filters and sorts environments across pages while preserving API fields' {
		& (Get-Module PpacEnvironmentBehaviorFixture) {
			$script:responses.Enqueue([pscustomobject]@{
					value             = @(
						[pscustomobject]@{ id = 'first'; displayName = 'Demo Z'; type = 'Sandbox'; state = 'Ready'; tenantId = 'tenant'; protectionLevel = 'Standard' }
						[pscustomobject]@{ id = 'other'; displayName = 'Unrelated' }
					)
					'@odata.nextLink' = 'https://api.powerplatform.com/environmentmanagement/environments?api-version=2024-10-01&$skip=2'
				})
			$script:responses.Enqueue([pscustomobject]@{
					value = @([pscustomobject]@{ id = 'second'; displayName = 'Demo A'; protectionLevel = 'Basic' })
				})
		}
		$environments = @(PpacEnvironmentBehaviorFixture\Get-PpacEnvironment -EnvironmentId 'Demo*')
		$environments.EnvName | Should -Be @('Demo A', 'Demo Z')
		$environments.PpacEnvId | Should -Be @('second', 'first')
		$environments[1].tenantId | Should -Be 'tenant'
		$environments[1].Sku | Should -Be 'Sandbox'
		$environments[1].State | Should -Be 'Ready'
		$environments[1].Managed | Should -BeTrue
		$environments[0].Managed | Should -BeFalse
	}

	It 'retrieves a GUID directly without requiring a successful collection lookup' {
		& (Get-Module PpacEnvironmentBehaviorFixture) {
			$script:responses.Enqueue([pscustomobject]@{
					id          = '11111111-1111-1111-1111-111111111111'
					displayName = 'Finance Demo'
				})
		}
		$environment = PpacEnvironmentBehaviorFixture\Get-PpacEnvironment -EnvironmentId '{11111111-1111-1111-1111-111111111111}'
		$environment.EnvId | Should -Be '11111111-1111-1111-1111-111111111111'
		$environment.PpacEnvName | Should -Be 'Finance Demo'
		$requests = @(& (Get-Module PpacEnvironmentBehaviorFixture) { $script:requests })
		$requests | Should -Be @('https://api.powerplatform.com/environmentmanagement/environments/11111111-1111-1111-1111-111111111111?api-version=2024-10-01')
	}

	It 'terminates when a later page fails rather than returning a partial inventory' {
		& (Get-Module PpacEnvironmentBehaviorFixture) {
			$script:responses.Enqueue([pscustomobject]@{
					value             = @([pscustomobject]@{ id = 'first'; displayName = 'Demo' })
					'@odata.nextLink' = 'https://api.powerplatform.com/environmentmanagement/environments?api-version=2024-10-01&$skip=1'
				})
			$script:responses.Enqueue([UnauthorizedAccessException]::new())
		}
		{ PpacEnvironmentBehaviorFixture\Get-PpacEnvironment -ErrorAction Stop } | Should -Throw -ExceptionType ([UnauthorizedAccessException])
	}

	It 'returns no environments for an empty inventory' {
		& (Get-Module PpacEnvironmentBehaviorFixture) {
			$script:responses.Enqueue([pscustomobject]@{ value = @() })
		}
		@(PpacEnvironmentBehaviorFixture\Get-PpacEnvironment).Count | Should -Be 0
	}
}
