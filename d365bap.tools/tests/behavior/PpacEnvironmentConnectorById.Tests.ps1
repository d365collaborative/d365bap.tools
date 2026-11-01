BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacEnvironmentConnectorByIdFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/Get-PpacConnectivityRoute.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentConnectorById.ps1')
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
			param($ResourceUrl)
			$null = $ResourceUrl
			$secure = [Security.SecureString]::new()
			foreach ($char in @('fixture-token'.ToCharArray())) { $secure.AppendChar($char) }
			$secure.MakeReadOnly()
			$secure
		}
		$script:requests = @()
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
		}
		Export-ModuleMember -Function Get-PpacEnvironmentConnectorById
	}
	Import-Module $fixture -Force
}

Describe 'Get-PpacEnvironmentConnectorById' {
	It 'uses one parameter set and returns one typed connector' {
		$cmd = Get-Command PpacEnvironmentConnectorByIdFixture\Get-PpacEnvironmentConnectorById
		$cmd.ParameterSets.Name | Should -Be '__AllParameterSets'

		& (Get-Module PpacEnvironmentConnectorByIdFixture) { $script:requests = @() }
		$result = PpacEnvironmentConnectorByIdFixture\Get-PpacEnvironmentConnectorById -EnvironmentId 'es-ude-motz-01' -ConnectorId 'shared_office365'
		$result.ConnectorName | Should -Be 'shared_office365'
		$result.DisplayName | Should -Be 'Office 365 Outlook'
		$result.PpacEnvId | Should -Be 'af6c129c-c893-e544-8b42-e38a584ba34c'
		$request = & (Get-Module PpacEnvironmentConnectorByIdFixture) { $script:requests[-1] }
		$request.Builder | Should -Be 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.Item.WithConnectorItemRequestBuilder'
		$request.RequestUrl | Should -Match '/connectors/shared_office365\?'
	}

	It 'normalizes a full connector resource id' {
		& (Get-Module PpacEnvironmentConnectorByIdFixture) { $script:requests = @() }
		$null = PpacEnvironmentConnectorByIdFixture\Get-PpacEnvironmentConnectorById -EnvironmentId 'es-ude-motz-01' -ConnectorId '/providers/Microsoft.PowerApps/apis/shared_office365'
		$request = & (Get-Module PpacEnvironmentConnectorByIdFixture) { $script:requests[-1] }
		$request.RequestUrl | Should -Match '/connectors/shared_office365\?'
	}

	It 'adds showAllDlpEnforceableApis when IncludeUnavailable is set' {
		& (Get-Module PpacEnvironmentConnectorByIdFixture) { $script:requests = @() }
		$null = PpacEnvironmentConnectorByIdFixture\Get-PpacEnvironmentConnectorById -EnvironmentId 'es-ude-motz-01' -ConnectorId 'shared_office365' -IncludeUnavailable
		$request = & (Get-Module PpacEnvironmentConnectorByIdFixture) { $script:requests[-1] }
		$request.RequestUrl | Should -Match 'showAllDlpEnforceableApis=true'
	}
}
