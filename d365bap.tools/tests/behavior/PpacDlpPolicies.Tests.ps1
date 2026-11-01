BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacDlpPolicyFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'functions/Get-PpacTenantDlpPolicy.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentDlpPolicy.ps1')
		function Test-PSFFunctionInterrupt { $false }
		function Stop-PSFFunction {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test fixture.')]
			param($Message, $Exception, $ErrorRecord)
			$null = $Exception
			$null = $ErrorRecord
			throw $Message
		}
		function Get-BapContext { [pscustomobject]@{ TenantId = '11111111-1111-1111-1111-111111111111'; TenantName = 'Fixture Tenant' } }
		function Get-Environment {
			param($EnvironmentId)
			if ("$EnvironmentId" -eq 'es-ude-motz-01') {
				[pscustomobject]@{
					PpacEnvId   = 'af6c129c-c893-e544-8b42-e38a584ba34c'
					PpacEnvName = 'es-ude-motz-01'
					EnvId       = 'af6c129c-c893-e544-8b42-e38a584ba34c'
				}
			}
		}
		function New-Policy {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test fixture.')]
			param(
				[string] $Id,
				[string] $DisplayName,
				[string] $EnvironmentType,
				[string] $Scope,
				[object[]] $Environments = @(),
				[object[]] $ConnectorGroups = @()
			)
			[pscustomobject]@{
				name                            = $Id
				displayName                     = $DisplayName
				environmentType                 = $EnvironmentType
				defaultConnectorsClassification = 'General'
				connectorGroups                 = $ConnectorGroups
				environments                    = $Environments
				createdBy                       = [pscustomobject]@{ displayName = 'Admin'; userPrincipalName = 'admin@contoso.com' }
				createdTime                     = [datetime]'2024-01-01T00:00:00Z'
				lastModifiedBy                  = [pscustomobject]@{ displayName = 'Admin'; userPrincipalName = 'admin@contoso.com' }
				lastModifiedTime                = [datetime]'2024-06-01T00:00:00Z'
				isLegacySchemaVersion           = $false
				PolicyScope                     = $Scope
				EnvironmentIds                  = @($Environments.id)
			}
		}
		$script:connectorGroups = @(
			[pscustomobject]@{
				classification = 'Confidential'
				connectors     = @(
					[pscustomobject]@{ id = '/providers/Microsoft.PowerApps/apis/shared_sql'; name = 'shared_sql'; type = 'Microsoft.PowerApps/apis' }
					[pscustomobject]@{ id = '/providers/Microsoft.PowerApps/apis/shared_office365'; name = 'shared_office365'; type = 'Microsoft.PowerApps/apis' }
				)
			}
		)
		$motz = [pscustomobject]@{ id = 'af6c129c-c893-e544-8b42-e38a584ba34c'; name = 'es-ude-motz-01'; type = '/providers/dummyEnvironments' }
		$other = [pscustomobject]@{ id = '99999999-9999-9999-9999-999999999999'; name = 'other-env'; type = '/providers/dummyEnvironments' }
		$tenantId = [pscustomobject]@{ id = '11111111-1111-1111-1111-111111111111'; name = 'Default-tenant'; type = '/providers/dummyEnvironments' }
		$script:policies = @(
			(New-Policy -Id '11111111-1111-1111-1111-111111111111' -DisplayName 'Tenant All' -EnvironmentType 'AllEnvironments' -Scope 'Tenant' -ConnectorGroups $script:connectorGroups)
			(New-Policy -Id '22222222-2222-2222-2222-222222222222' -DisplayName 'Tenant Only Motz' -EnvironmentType 'OnlyEnvironments' -Scope 'Tenant' -Environments @($motz))
			(New-Policy -Id '33333333-3333-3333-3333-333333333333' -DisplayName 'Tenant Except Motz' -EnvironmentType 'ExceptEnvironments' -Scope 'Tenant' -Environments @($motz))
			(New-Policy -Id '44444444-4444-4444-4444-444444444444' -DisplayName 'Tenant Except Other' -EnvironmentType 'ExceptEnvironments' -Scope 'Tenant' -Environments @($other))
			(New-Policy -Id '55555555-5555-5555-5555-555555555555' -DisplayName 'Environment Motz' -EnvironmentType 'SingleEnvironment' -Scope 'Environment' -Environments @($motz))
			(New-Policy -Id '66666666-6666-6666-6666-666666666666' -DisplayName 'Environment Other' -EnvironmentType 'SingleEnvironment' -Scope 'Environment' -Environments @($other))
			(New-Policy -Id '77777777-7777-7777-7777-777777777777' -DisplayName 'Shared Name' -EnvironmentType 'AllEnvironments' -Scope 'Tenant')
			(New-Policy -Id '88888888-8888-8888-8888-888888888888' -DisplayName 'Shared Name' -EnvironmentType 'AllEnvironments' -Scope 'Tenant')
			(New-Policy -Id 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -DisplayName 'Tenant Default Only' -EnvironmentType 'OnlyEnvironments' -Scope 'Tenant' -Environments @($tenantId))
		)
		function Get-BapDlpPolicy { $script:policies }
		$script:exported = @()
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
		Export-ModuleMember -Function Get-PpacTenantDlpPolicy, Get-PpacEnvironmentDlpPolicy
	}
	Import-Module $fixture -Force
}

Describe 'Get-PpacTenantDlpPolicy' {
	It 'returns only tenant-scoped policies' {
		$result = @(PpacDlpPolicyFixture\Get-PpacTenantDlpPolicy)
		$result.Count | Should -Be 7
		@($result | Where-Object PolicyScope -ne 'Tenant').Count | Should -Be 0
		$result[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacTenantDlpPolicy'
	}

	It 'summarizes connector groups and environments' {
		$result = @(PpacDlpPolicyFixture\Get-PpacTenantDlpPolicy -PolicyId 'Tenant All')
		$result.Count | Should -Be 1
		$result[0].PolicyId | Should -Be '11111111-1111-1111-1111-111111111111'
		$result[0].ConnectorGroupCount | Should -Be 1
		$result[0].ConnectorCount | Should -Be 2
		$result[0].EnvironmentCount | Should -Be 0
		$result[0].CreatedBy | Should -Be 'Admin'
	}

	It 'filters by wildcard and returns all name matches for PolicyId' {
		$filtered = @(PpacDlpPolicyFixture\Get-PpacTenantDlpPolicy -PolicyId '*except*')
		$filtered.Count | Should -Be 2
		$byName = @(PpacDlpPolicyFixture\Get-PpacTenantDlpPolicy -PolicyId 'Shared Name')
		$byName.Count | Should -Be 2
	}

	It 'does not return environment-scoped policies by id' {
		$result = @(PpacDlpPolicyFixture\Get-PpacTenantDlpPolicy -PolicyId '55555555-5555-5555-5555-555555555555')
		$result.Count | Should -Be 0
	}

	It 'exports tenant policies' {
		& (Get-Module PpacDlpPolicyFixture) { $script:exported = @() }
		$result = @(PpacDlpPolicyFixture\Get-PpacTenantDlpPolicy -AsExcelOutput)
		$result.Count | Should -Be 0
		$export = & (Get-Module PpacDlpPolicyFixture) { $script:exported[-1] }
		$export.WorksheetName | Should -Be 'Get-PpacTenantDlpPolicy'
	}
}

Describe 'Get-PpacEnvironmentDlpPolicy' {
	It 'returns effective inherited and environment policies' {
		$result = @(PpacDlpPolicyFixture\Get-PpacEnvironmentDlpPolicy -EnvironmentId 'es-ude-motz-01')
		($result.Name -contains 'Tenant All') | Should -Be $true
		($result.Name -contains 'Tenant Only Motz') | Should -Be $true
		($result.Name -contains 'Tenant Except Motz') | Should -Be $false
		($result.Name -contains 'Tenant Except Other') | Should -Be $true
		($result.Name -contains 'Environment Motz') | Should -Be $true
		($result.Name -contains 'Environment Other') | Should -Be $false
		@($result | Where-Object { -not $_.IsEffective }).Count | Should -Be 0
		($result | Where-Object Name -EQ 'Tenant All').IsInherited | Should -Be $true
		($result | Where-Object Name -EQ 'Environment Motz').IsInherited | Should -Be $false
		$result[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacEnvironmentDlpPolicy'
	}

	It 'marks a non-effective tenant policy when queried by id' {
		$result = @(PpacDlpPolicyFixture\Get-PpacEnvironmentDlpPolicy -EnvironmentId 'es-ude-motz-01' -PolicyId '33333333-3333-3333-3333-333333333333')
		$result.Count | Should -Be 1
		$result[0].IsEffective | Should -Be $false
		$result[0].IsInherited | Should -Be $true
	}

	It 'marks a non-effective environment policy when queried by id' {
		$result = @(PpacDlpPolicyFixture\Get-PpacEnvironmentDlpPolicy -EnvironmentId 'es-ude-motz-01' -PolicyId '66666666-6666-6666-6666-666666666666')
		$result.Count | Should -Be 1
		$result[0].IsEffective | Should -Be $false
		$result[0].IsInherited | Should -Be $false
	}

	It 'resolves the default environment from the current tenant id' {
		$result = @(PpacDlpPolicyFixture\Get-PpacEnvironmentDlpPolicy -EnvironmentId '11111111-1111-1111-1111-111111111111')
		($result.Name -contains 'Tenant Default Only') | Should -Be $true
		$item = $result | Where-Object Name -EQ 'Tenant Default Only'
		$item.PpacEnvId | Should -Be 'Default-11111111-1111-1111-1111-111111111111'
	}

	It 'exports effective policies' {
		& (Get-Module PpacDlpPolicyFixture) { $script:exported = @() }
		$result = @(PpacDlpPolicyFixture\Get-PpacEnvironmentDlpPolicy -EnvironmentId 'es-ude-motz-01' -AsExcelOutput)
		$result.Count | Should -Be 0
		$export = & (Get-Module PpacDlpPolicyFixture) { $script:exported[-1] }
		$export.WorksheetName | Should -Be 'Get-PpacEnvironmentDlpPolicy'
	}
}
