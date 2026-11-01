BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacEnvironmentConnectionFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/Get-PpacConnectivityRoute.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentConnection.ps1')
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
		$script:connections = @(
			[pscustomobject]@{
				id         = '/providers/Microsoft.PowerApps/connections/aaa111'
				name       = 'aaa111'
				type       = 'Microsoft.PowerApps/connections'
				properties = [pscustomobject]@{
					displayName      = 'Contoso Salesforce'
					apiId            = '/providers/Microsoft.PowerApps/apis/shared_salesforce'
					accountName      = 'maker@contoso.com'
					statuses         = @([pscustomobject]@{ status = 'Connected'; target = 'https://contoso.example' })
					createdBy        = [pscustomobject]@{ userPrincipalName = 'creator@contoso.com'; displayName = 'Creator' }
					createdTime      = [datetime]'2024-01-01T00:00:00Z'
					lastModifiedTime = [datetime]'2024-06-01T00:00:00Z'
					expirationTime   = $null
					allowSharing     = $true
					isSsoConnection  = $false
					environment      = [pscustomobject]@{ id = 'af6c129c-c893-e544-8b42-e38a584ba34c'; name = 'es-ude-motz-01' }
				}
			}
			[pscustomobject]@{
				id         = '/providers/Microsoft.PowerApps/connections/bbb222'
				name       = 'bbb222'
				type       = 'Microsoft.PowerApps/connections'
				properties = [pscustomobject]@{
					displayName      = 'Office 365 Outlook'
					apiId            = '/providers/Microsoft.PowerApps/apis/shared_office365'
					accountName      = 'user@contoso.com'
					statuses         = @([pscustomobject]@{ status = 'Connected'; target = 'https://outlook.example' })
					createdBy        = [pscustomobject]@{ userPrincipalName = 'creator@contoso.com'; displayName = 'Creator' }
					createdTime      = [datetime]'2024-02-01T00:00:00Z'
					lastModifiedTime = [datetime]'2024-07-01T00:00:00Z'
					expirationTime   = [datetime]'2025-01-01T00:00:00Z'
					allowSharing     = $false
					isSsoConnection  = $true
					environment      = [pscustomobject]@{ id = 'af6c129c-c893-e544-8b42-e38a584ba34c'; name = 'es-ude-motz-01' }
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
			[pscustomobject]@{ value = @($script:connections) }
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
		Export-ModuleMember -Function Get-PpacEnvironmentConnection
	}
	Import-Module $fixture -Force
}

Describe 'Get-PpacEnvironmentConnection parameter sets' {
	It 'requires an environment id' {
		$cmd = Get-Command PpacEnvironmentConnectionFixture\Get-PpacEnvironmentConnection
		$cmd.Parameters['EnvironmentId'].ParameterSets.Values.IsMandatory | Should -Contain $true
	}
}

Describe 'Get-PpacEnvironmentConnection list behavior' {
	It 'returns typed connection rows and sends the connection request' {
		& (Get-Module PpacEnvironmentConnectionFixture) { $script:requests = @() }
		$result = @(PpacEnvironmentConnectionFixture\Get-PpacEnvironmentConnection -EnvironmentId 'es-ude-motz-01')
		$result.Count | Should -Be 2
		$result[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacEnvironmentConnection'
		$result[0].ConnectionId | Should -Be '/providers/Microsoft.PowerApps/connections/aaa111'
		$result[0].ConnectorId | Should -Be '/providers/Microsoft.PowerApps/apis/shared_salesforce'
		$result[0].ConnectorName | Should -Be 'shared_salesforce'
		$result[0].Status | Should -Be 'Connected'
		$result[0].CreatedBy | Should -Be 'creator@contoso.com'
		$result[0].EnvironmentId | Should -Be 'af6c129c-c893-e544-8b42-e38a584ba34c'
		$result[0].PpacEnvId | Should -Be 'af6c129c-c893-e544-8b42-e38a584ba34c'
		$request = & (Get-Module PpacEnvironmentConnectionFixture) { $script:requests[-1] }
		$request.Builder | Should -Be 'Microsoft.PowerPlatform.Management.Connectivity.Environments.Item.Connections.ConnectionsRequestBuilder'
		$request.RequestUrl | Should -Match '/connectivity/environments/af6c129c-c893-e544-8b42-e38a584ba34c/connections\?api-version=2024-10-01$'
		$request.RequestUrl | Should -Not -Match '\$filter='
	}

	It 'filters by connector short name and display name' {
		$byConnector = @(PpacEnvironmentConnectionFixture\Get-PpacEnvironmentConnection -EnvironmentId 'es-ude-motz-01' -Name 'shared_salesforce')
		$byConnector.Count | Should -Be 1
		$byConnector[0].ConnectorName | Should -Be 'shared_salesforce'
		$byDisplay = @(PpacEnvironmentConnectionFixture\Get-PpacEnvironmentConnection -EnvironmentId 'es-ude-motz-01' -Name '*outlook*')
		$byDisplay.Count | Should -Be 1
		$byDisplay[0].DisplayName | Should -Be 'Office 365 Outlook'
	}

	It 'resolves the default environment from the current tenant id' {
		& (Get-Module PpacEnvironmentConnectionFixture) { $script:requests = @() }
		$null = @(PpacEnvironmentConnectionFixture\Get-PpacEnvironmentConnection -EnvironmentId '11111111-1111-1111-1111-111111111111')
		$request = & (Get-Module PpacEnvironmentConnectionFixture) { $script:requests[-1] }
		$request.RequestUrl | Should -Match 'connectivity/environments/Default-11111111-1111-1111-1111-111111111111/connections'
	}
}

Describe 'Get-PpacEnvironmentConnection Excel output' {
	It 'exports matching rows and returns no pipeline objects' {
		& (Get-Module PpacEnvironmentConnectionFixture) { $script:exported = @() }
		$result = @(PpacEnvironmentConnectionFixture\Get-PpacEnvironmentConnection -EnvironmentId 'es-ude-motz-01' -AsExcelOutput)
		$result.Count | Should -Be 0
		$export = & (Get-Module PpacEnvironmentConnectionFixture) { $script:exported[-1] }
		$export.WorksheetName | Should -Be 'Get-PpacEnvironmentConnection'
		$export.InputObject | Should -Not -BeNullOrEmpty
	}
}
