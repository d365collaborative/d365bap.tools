BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacGovernancePolicyFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/Get-BapGovernancePolicyView.ps1')
		. (Join-Path $Root 'internal/functions/ConvertTo-PpacAcpPolicy.ps1')
		. (Join-Path $Root 'functions/Get-PpacTenantRuleBasedPolicy.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentRuleBasedPolicy.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentGroupRuleBasedPolicy.ps1')
		. (Join-Path $Root 'functions/Get-PpacTenantAcpPolicy.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentAcpPolicy.ps1')
		. (Join-Path $Root 'functions/Get-PpacEnvironmentGroupAcpPolicy.ps1')
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
				[pscustomobject]@{ PpacEnvId = 'af6c129c-c893-e544-8b42-e38a584ba34c'; PpacEnvName = 'es-ude-motz-01' }
			}
		}
		$script:allowed = @(
			[pscustomobject]@{
				AllowedConnector           = '/providers/Microsoft.PowerApps/apis/shared_office365'
				AllowedActionsMode         = 'AllAllowed'
				AllowedConnectionTypesMode = 'AllAllowed'
			}
			[pscustomobject]@{
				AllowedConnector           = '/providers/Microsoft.PowerApps/apis/shared_sql'
				AllowedActionsMode         = 'SomeAllowed'
				AllowedActions             = @('GetItem', 'CreateRecord')
				AllowedConnectionTypesMode = 'AllAllowed'
			}
		)
		$script:policies = @(
			[pscustomobject]@{
				id           = '11111111-1111-1111-1111-111111111111'
				name         = 'ACP Baseline'
				lastModified = [datetime]'2024-06-01T00:00:00Z'
				ruleSetCount = 1
				ruleSets     = @(
					[pscustomobject]@{
						id      = 'ConnectorManagement'
						version = '1.0'
						inputs  = [pscustomobject]@{ AllowedConnectorList = $script:allowed }
					}
				)
				tenantId     = '11111111-1111-1111-1111-111111111111'
			}
			[pscustomobject]@{
				id           = '22222222-2222-2222-2222-222222222222'
				name         = 'ACP Restricted'
				lastModified = [datetime]'2024-07-01T00:00:00Z'
				ruleSetCount = 1
				ruleSets     = @(
					[pscustomobject]@{
						id      = 'ConnectorManagement'
						version = '1.0'
						inputs  = [pscustomobject]@{ AllowedConnectorList = @($script:allowed[0]) }
					}
				)
				tenantId     = '11111111-1111-1111-1111-111111111111'
			}
			[pscustomobject]@{
				id           = '33333333-3333-3333-3333-333333333333'
				name         = 'Sharing Policy'
				lastModified = [datetime]'2024-08-01T00:00:00Z'
				ruleSetCount = 1
				ruleSets     = @(
					[pscustomobject]@{
						id      = 'Sharing'
						version = '1.0'
						inputs  = [pscustomobject]@{}
					}
				)
				tenantId     = '11111111-1111-1111-1111-111111111111'
			}
		)
		$script:environmentAssignments = @(
			[pscustomobject]@{
				policyId     = '11111111-1111-1111-1111-111111111111'
				resourceId   = 'af6c129c-c893-e544-8b42-e38a584ba34c'
				resourceType = 'EnvironmentGroup'
				ruleSetCount = 1
				tenantId     = '11111111-1111-1111-1111-111111111111'
			}
		)
		$script:groupAssignments = @(
			[pscustomobject]@{
				policyId     = '22222222-2222-2222-2222-222222222222'
				resourceId   = 'group-1'
				resourceType = 'EnvironmentGroup'
				ruleSetCount = 1
				tenantId     = '11111111-1111-1111-1111-111111111111'
			}
		)
		function Get-BapGovernancePolicy { $script:policies }
		function Get-BapGovernancePolicyAssignment {
			param($EnvironmentId, $EnvironmentGroupId)
			if (-not [string]::IsNullOrWhiteSpace("$EnvironmentGroupId")) { return $script:groupAssignments }
			if ("$EnvironmentId" -like '*af6c*') { return $script:environmentAssignments }
			@()
		}
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
		Export-ModuleMember -Function Get-PpacTenantRuleBasedPolicy, Get-PpacEnvironmentRuleBasedPolicy, Get-PpacEnvironmentGroupRuleBasedPolicy, Get-PpacTenantAcpPolicy, Get-PpacEnvironmentAcpPolicy, Get-PpacEnvironmentGroupAcpPolicy
	}
	Import-Module $fixture -Force
}

Describe 'General rule-based policy commands' {
	It 'lists tenant policies and derives the ACP kind' {
		$result = @(PpacGovernancePolicyFixture\Get-PpacTenantRuleBasedPolicy)
		$result.Count | Should -Be 3
		@($result | Where-Object Kind -eq 'Acp').Count | Should -Be 2
		@($result | Where-Object Kind -eq 'Other').Count | Should -Be 1
		$result[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacTenantRuleBasedPolicy'
	}

	It 'filters tenant policies by kind, name, and id' {
		$acp = @(PpacGovernancePolicyFixture\Get-PpacTenantRuleBasedPolicy -Kind Acp)
		$acp.Count | Should -Be 2
		$byName = @(PpacGovernancePolicyFixture\Get-PpacTenantRuleBasedPolicy -PolicyId '*restricted*')
		$byName.Count | Should -Be 1
		$byId = @(PpacGovernancePolicyFixture\Get-PpacTenantRuleBasedPolicy -PolicyId 'ACP Baseline')
		$byId.Count | Should -Be 1
	}

	It 'returns inherited environment policies and marks non-effective ids' {
		$effective = @(PpacGovernancePolicyFixture\Get-PpacEnvironmentRuleBasedPolicy -EnvironmentId 'es-ude-motz-01')
		$effective.Count | Should -Be 1
		$effective[0].Name | Should -Be 'ACP Baseline'
		$effective[0].AssignmentSource | Should -Be 'Inherited'
		$effective[0].IsEffective | Should -Be $true
		$effective[0].PpacEnvId | Should -Be 'af6c129c-c893-e544-8b42-e38a584ba34c'
		$nonEffective = @(PpacGovernancePolicyFixture\Get-PpacEnvironmentRuleBasedPolicy -EnvironmentId 'es-ude-motz-01' -PolicyId 'ACP Restricted')
		$nonEffective.Count | Should -Be 1
		$nonEffective[0].IsEffective | Should -Be $false
		$nonEffective[0].AssignmentSource | Should -Be 'None'
	}

	It 'returns direct group assignments' {
		$result = @(PpacGovernancePolicyFixture\Get-PpacEnvironmentGroupRuleBasedPolicy -EnvironmentGroupId 'group-1')
		$result.Count | Should -Be 1
		$result[0].Name | Should -Be 'ACP Restricted'
		$result[0].AssignmentSource | Should -Be 'Direct'
		$result[0].EnvironmentGroupId | Should -Be 'group-1'
	}
}

Describe 'ACP policy commands' {
	It 'returns tenant ACP policies with allowlist summaries' {
		$result = @(PpacGovernancePolicyFixture\Get-PpacTenantAcpPolicy)
		$result.Count | Should -Be 2
		$result[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacTenantAcpPolicy'
		($result | Where-Object Name -EQ 'ACP Baseline').AllowedConnectorCount | Should -Be 2
		($result | Where-Object Name -EQ 'ACP Baseline').RuleSetVersion | Should -Be '1.0'
	}

	It 'expands tenant ACP connectors' {
		$rows = @(PpacGovernancePolicyFixture\Get-PpacTenantAcpPolicy -ExpandConnectors)
		$rows.Count | Should -Be 3
		$rows[0].PSObject.TypeNames | Should -Contain 'D365Bap.Tools.PpacAcpConnector'
		($rows | Where-Object ConnectorName -EQ 'shared_sql').AllowedActions | Should -Be 'GetItem, CreateRecord'
	}

	It 'returns and expands the effective environment ACP policy' {
		$policy = @(PpacGovernancePolicyFixture\Get-PpacEnvironmentAcpPolicy -EnvironmentId 'es-ude-motz-01')
		$policy.Count | Should -Be 1
		$policy[0].AssignmentSource | Should -Be 'Inherited'
		$rows = @(PpacGovernancePolicyFixture\Get-PpacEnvironmentAcpPolicy -EnvironmentId 'es-ude-motz-01' -ExpandConnectors)
		$rows.Count | Should -Be 2
		$rows[0].PpacEnvId | Should -Be 'af6c129c-c893-e544-8b42-e38a584ba34c'
	}

	It 'returns and expands the group ACP policy' {
		$policy = @(PpacGovernancePolicyFixture\Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId 'group-1')
		$policy.Count | Should -Be 1
		$policy[0].AssignmentSource | Should -Be 'Direct'
		$rows = @(PpacGovernancePolicyFixture\Get-PpacEnvironmentGroupAcpPolicy -EnvironmentGroupId 'group-1' -ExpandConnectors)
		$rows.Count | Should -Be 1
		$rows[0].ConnectorName | Should -Be 'shared_office365'
		$rows[0].EnvironmentGroupId | Should -Be 'group-1'
	}

	It 'exports ACP policy rows' {
		& (Get-Module PpacGovernancePolicyFixture) { $script:exported = @() }
		$result = @(PpacGovernancePolicyFixture\Get-PpacTenantAcpPolicy -AsExcelOutput)
		$result.Count | Should -Be 0
		$export = & (Get-Module PpacGovernancePolicyFixture) { $script:exported[-1] }
		$export.WorksheetName | Should -Be 'Get-PpacTenantAcpPolicy'
	}
}
