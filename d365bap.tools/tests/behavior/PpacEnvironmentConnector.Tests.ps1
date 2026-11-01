BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacEnvironmentConnectorFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/Get-PpacConnectivityRoute.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentConnector.ps1')
		function Test-PSFFunctionInterrupt { $false }
		function Stop-PSFFunction {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test fixture.')]
			param($Message, $Exception, $ErrorRecord)
			$null = $Exception
			$null = $ErrorRecord
			throw $Message
		}
		function Get-BapContext { [pscustomobject]@{ TenantId = '11111111-1111-1111-1111-111111111111'; TenantName = 'Fixture Tenant' } }
		function Get-BapEnvironment {
			param($EnvironmentId)
			if ("$EnvironmentId" -eq 'es-ude-motz-01') {
				[pscustomobject]@{ PpacEnvId = 'af6c129c-c893-e544-8b42-e38a584ba34c'; PpacEnvName = 'es-ude-motz-01' }
			}
		}
		function Get-BapAccessToken {
			param($ResourceUrl, [switch] $PowerPlatform)
			$null = $ResourceUrl
			$null = $PowerPlatform
			$secure = [Security.SecureString]::new()
			foreach ($char in @('fixture-token'.ToCharArray())) { $secure.AppendChar($char) }
			$secure.MakeReadOnly()
			$secure
		}
		$script:requests = @()
		$script:exported = @()
		$script:connectors = @(
			[pscustomobject]@{
				id         = '/providers/Microsoft.PowerApps/apis/shared_office365'
				name       = 'shared_office365'
				type       = 'Microsoft.PowerApps/apis'
				properties = [pscustomobject]@{
					displayName    = 'Office 365 Outlook'
					publisher      = 'Microsoft'
					tier           = 'Standard'
					releaseTag     = 'Production'
					isCustomApi    = $false
					apiEnvironment = 'Shared'
					capabilities   = @('actions')
					createdTime    = [datetime]'2024-01-01T00:00:00Z'
					changedTime    = [datetime]'2024-06-01T00:00:00Z'
					description    = 'Office 365 fixture'
				}
			}
			[pscustomobject]@{
				id         = '/providers/Microsoft.PowerApps/apis/shared_salesforce'
				name       = 'shared_salesforce'
				type       = 'Microsoft.PowerApps/apis'
				properties = [pscustomobject]@{
					displayName    = 'Salesforce'
					publisher      = 'Salesforce'
					tier           = 'Premium'
					releaseTag     = 'Production'
					isCustomApi    = $false
					apiEnvironment = 'Shared'
					capabilities   = @('actions', 'triggers')
					createdTime    = [datetime]'2024-02-01T00:00:00Z'
					changedTime    = [datetime]'2024-07-01T00:00:00Z'
					description    = 'Salesforce fixture'
				}
			}
		)
		function Invoke-BapSdkRequest {
			param($Resource, $Method, $EnvironmentId, $Body, $Token, $RequestUrl)
			$null = $Body
			$null = $Token
			$script:requests += [pscustomobject]@{
				Builder       = "$($Resource.Builder)"
				Method        = $Method
				EnvironmentId = $EnvironmentId
				RequestUrl    = $RequestUrl
			}
			[pscustomobject]@{ value = @($script:connectors) }
		}
		function Export-Excel {
			param(
				[Parameter(ValueFromPipeline = $true)]
				$InputObject,
				[string] $WorksheetName
			)
			process {
				$script:exported += [pscustomobject]@{ InputObject = $InputObject; WorksheetName = $WorksheetName }
			}
		}
		Export-ModuleMember -Function Get-PpacEnvironmentConnector
	}
	Import-Module $fixture -Force
}

Describe 'Get-PpacEnvironmentConnector list behavior' {
	It 'returns typed connector rows and sends the environment filter' {
		& (Get-Module PpacEnvironmentConnectorFixture) { $script:requests = @() }
		$result = @(PpacEnvironmentConnectorFixture\Get-PpacEnvironmentConnector -EnvironmentId 'es-ude-motz-01')
		$result.Count | Should -Be 2
		$result[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacEnvironmentConnector'
		$result[0].ConnectorId | Should -Be '/providers/Microsoft.PowerApps/apis/shared_office365'
		$result[0].ConnectorName | Should -Be 'shared_office365'
		$result[0].DisplayName | Should -Be 'Office 365 Outlook'
		$result[0].PpacEnvId | Should -Be 'af6c129c-c893-e544-8b42-e38a584ba34c'
		$result[0].PpacEnvName | Should -Be 'es-ude-motz-01'
		$request = & (Get-Module PpacEnvironmentConnectorFixture) { $script:requests[-1] }
		$request.Builder | Should -Be 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.ConnectorsRequestBuilder'
		$request.RequestUrl | Should -Match '\$filter=environment%20eq%20%27af6c129c-c893-e544-8b42-e38a584ba34c%27'
		$request.RequestUrl | Should -Match 'api-version=2024-10-01'
	}

	It 'filters by name and display name with wildcards' {
		& (Get-Module PpacEnvironmentConnectorFixture) { $script:requests = @() }
		$result = @(PpacEnvironmentConnectorFixture\Get-PpacEnvironmentConnector -EnvironmentId 'es-ude-motz-01' -Name '*sales*')
		$result.Count | Should -Be 1
		$result[0].ConnectorName | Should -Be 'shared_salesforce'
	}

	It 'resolves the default environment from the current tenant id' {
		& (Get-Module PpacEnvironmentConnectorFixture) { $script:requests = @() }
		$null = @(PpacEnvironmentConnectorFixture\Get-PpacEnvironmentConnector -EnvironmentId '11111111-1111-1111-1111-111111111111')
		$request = & (Get-Module PpacEnvironmentConnectorFixture) { $script:requests[-1] }
		$request.RequestUrl | Should -Match 'connectivity/environments/Default-11111111-1111-1111-1111-111111111111'
		$request.RequestUrl | Should -Match 'environment%20eq%20%27Default-11111111-1111-1111-1111-111111111111%27'
	}
}

Describe 'Get-PpacEnvironmentConnector Excel output' {
	It 'exports matching rows and returns no pipeline objects' {
		& (Get-Module PpacEnvironmentConnectorFixture) { $script:exported = @() }
		$result = @(PpacEnvironmentConnectorFixture\Get-PpacEnvironmentConnector -EnvironmentId 'es-ude-motz-01' -AsExcelOutput)
		$result.Count | Should -Be 0
		$export = & (Get-Module PpacEnvironmentConnectorFixture) { $script:exported[-1] }
		$export.WorksheetName | Should -Be 'Get-PpacEnvironmentConnector'
		$export.InputObject | Should -Not -BeNullOrEmpty
	}
}
