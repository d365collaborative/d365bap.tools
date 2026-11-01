BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacTenantConnectorFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'functions/Get-PpacTenantConnector.ps1')
		function Test-PSFFunctionInterrupt { $false }
		function Stop-PSFFunction {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test fixture.')]
			param($Message, $Exception, $ErrorRecord)
			$null = $Exception
			$null = $ErrorRecord
			throw $Message
		}
		function Get-BapContext { [pscustomobject]@{ TenantId = '11111111-1111-1111-1111-111111111111'; TenantName = 'Fixture Tenant' } }
		function Get-BapAccessToken {
			param($ResourceUrl)
			$null = $ResourceUrl
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
			if ("$($Resource.Builder)" -like '*WithConnectorItemRequestBuilder') {
				return $script:connectors | Where-Object { $RequestUrl -match [regex]::Escape("/connectors/$($_.name)") } | Select-Object -First 1
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
		Export-ModuleMember -Function Get-PpacTenantConnector
	}
	Import-Module $fixture -Force
}

Describe 'Get-PpacTenantConnector' {
	It 'uses one parameter set and lists the tenant catalog from the default environment' {
		$cmd = Get-Command PpacTenantConnectorFixture\Get-PpacTenantConnector
		$cmd.ParameterSets.Name | Should -Be '__AllParameterSets'

		& (Get-Module PpacTenantConnectorFixture) { $script:requests = @() }
		$result = @(PpacTenantConnectorFixture\Get-PpacTenantConnector)
		$result.Count | Should -Be 2
		$result[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacTenantConnector'
		$result[0].PpacTenantId | Should -Be '11111111-1111-1111-1111-111111111111'
		$request = & (Get-Module PpacTenantConnectorFixture) { $script:requests[-1] }
		$request.RequestUrl | Should -Match 'connectivity/environments/Default-11111111-1111-1111-1111-111111111111/connectors'
		$request.RequestUrl | Should -Match 'showAllDlpEnforceableApis=true'
	}

	It 'filters by name' {
		$result = @(PpacTenantConnectorFixture\Get-PpacTenantConnector -Name '*sales*')
		$result.Count | Should -Be 1
		$result[0].ConnectorName | Should -Be 'shared_salesforce'
	}

	It 'returns one connector by id and normalizes the full path' {
		& (Get-Module PpacTenantConnectorFixture) { $script:requests = @() }
		$result = PpacTenantConnectorFixture\Get-PpacTenantConnector -ConnectorId '/providers/Microsoft.PowerApps/apis/shared_office365'
		$result.ConnectorName | Should -Be 'shared_office365'
		$request = & (Get-Module PpacTenantConnectorFixture) { $script:requests[-1] }
		$request.Builder | Should -Be 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connectors.Item.WithConnectorItemRequestBuilder'
		$request.RequestUrl | Should -Match '/connectors/shared_office365\?'
	}

	It 'rejects name and connector id together' {
		{ PpacTenantConnectorFixture\Get-PpacTenantConnector -Name '*sql*' -ConnectorId 'shared_sql' -ErrorAction Stop } | Should -Throw
	}

	It 'exports the catalog' {
		& (Get-Module PpacTenantConnectorFixture) { $script:exported = @() }
		$result = @(PpacTenantConnectorFixture\Get-PpacTenantConnector -AsExcelOutput)
		$result.Count | Should -Be 0
		$export = & (Get-Module PpacTenantConnectorFixture) { $script:exported[-1] }
		$export.WorksheetName | Should -Be 'Get-PpacTenantConnector'
	}
}
