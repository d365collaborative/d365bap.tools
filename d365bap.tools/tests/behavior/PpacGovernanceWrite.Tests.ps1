BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacGovernanceWriteFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'functions/New-PpacTenantRuleBasedPolicy.ps1')
		. (Join-Path $Root 'functions/Set-PpacTenantRuleBasedPolicy.ps1')
		. (Join-Path $Root 'functions/Add-PpacEnvironmentRuleBasedPolicyAssignment.ps1')
		. (Join-Path $Root 'functions/Add-PpacEnvironmentGroupRuleBasedPolicyAssignment.ps1')
		. (Join-Path $Root 'functions/New-PpacTenantAcpPolicy.ps1')
		. (Join-Path $Root 'functions/Set-PpacTenantAcpPolicy.ps1')
		. (Join-Path $Root 'functions/Add-PpacEnvironmentAcpPolicyAssignment.ps1')
		. (Join-Path $Root 'functions/Add-PpacEnvironmentGroupAcpPolicyAssignment.ps1')
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
		$script:calls = @()
		function Invoke-RestMethod {
			param($Method, $Uri, $Headers, $Body, $ContentType)
			$null = $Headers
			$null = $ContentType
			$script:calls += [pscustomobject]@{ Method = $Method; Uri = $Uri; Body = $Body }
			if ($Method -eq 'Post' -and $Uri -like '*ruleBasedPolicies?*') {
				return [pscustomobject]@{ id = '11111111-1111-1111-1111-111111111111'; name = 'Created'; ruleSets = @() }
			}
			[pscustomobject]@{}
		}
		$script:policy = [pscustomobject]@{
			PolicyId              = '11111111-1111-1111-1111-111111111111'
			Name                  = 'ACP Baseline'
			Kind                  = 'Acp'
			LastModified          = [datetime]'2024-06-01'
			RuleSetCount          = 1
			RuleSetIds            = 'ConnectorManagement'
			AssignmentSource      = 'Definition'
			IsEffective           = $true
			TenantId              = '11111111-1111-1111-1111-111111111111'
			AllowedConnectorCount = 1
			RuleSets              = @(
				[pscustomobject]@{
					id      = 'ConnectorManagement'
					version = '1.0'
					inputs  = [pscustomobject]@{
						AllowedConnectorList = @(
							[pscustomobject]@{
								AllowedConnector           = '/providers/Microsoft.PowerApps/apis/shared_office365'
								AllowedActionsMode         = 'AllAllowed'
								AllowedConnectionTypesMode = 'AllAllowed'
							}
						)
					}
				}
			)
		}
		function Get-PpacTenantRuleBasedPolicy { param($PolicyId) $script:policy }
		function Get-PpacEnvironmentRuleBasedPolicy { param($EnvironmentId, $PolicyId) $script:policy }
		function Get-PpacEnvironmentGroupRuleBasedPolicy { param($EnvironmentGroupId, $PolicyId) $script:policy }
		function Get-PpacTenantAcpPolicy { param($PolicyId) $script:policy }
		function Get-PpacEnvironmentAcpPolicy { param($EnvironmentId, $PolicyId) $script:policy }
		function Get-PpacEnvironmentGroupAcpPolicy { param($EnvironmentGroupId, $PolicyId) $script:policy }
		Export-ModuleMember -Function New-PpacTenantRuleBasedPolicy, Set-PpacTenantRuleBasedPolicy, Add-PpacEnvironmentRuleBasedPolicyAssignment, Add-PpacEnvironmentGroupRuleBasedPolicyAssignment, New-PpacTenantAcpPolicy, Set-PpacTenantAcpPolicy, Add-PpacEnvironmentAcpPolicyAssignment, Add-PpacEnvironmentGroupAcpPolicyAssignment
	}
	Import-Module $fixture -Force
}

Describe 'Governance write commands' {
	It 'creates a rule-based policy with POST' {
		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$result = @(PpacGovernanceWriteFixture\New-PpacTenantRuleBasedPolicy -Name 'New policy' -RuleSet @(@{ id = 'Sharing'; version = '1.0'; inputs = @{} }) -Confirm:$false)
		$result.Count | Should -Be 1
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Post'
		$call.Uri | Should -Match 'governance/ruleBasedPolicies\?api-version=2024-10-01'
		$call.Body | Should -Match 'Sharing'
	}

	It 'updates a rule-based policy with PUT and PATCH' {
		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\Set-PpacTenantRuleBasedPolicy -PolicyId '11111111-1111-1111-1111-111111111111' -Name 'Updated' -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Put'
		$call.Body | Should -Match 'Updated'

		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\Set-PpacTenantRuleBasedPolicy -PolicyId '11111111-1111-1111-1111-111111111111' -RuleSet @(@{ id = 'Sharing'; version = '1.0'; inputs = @{} }) -Merge -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Patch'
	}

	It 'assigns a policy to an environment and group' {
		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\Add-PpacEnvironmentRuleBasedPolicyAssignment -EnvironmentId 'es-ude-motz-01' -PolicyId '11111111-1111-1111-1111-111111111111' -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Post'
		$call.Uri | Should -Match '/environments/af6c129c-c893-e544-8b42-e38a584ba34c/assignments'

		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\Add-PpacEnvironmentGroupRuleBasedPolicyAssignment -EnvironmentGroupId 'group-1' -PolicyId '11111111-1111-1111-1111-111111111111' -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Uri | Should -Match '/environmentGroups/group-1/assignments'
	}
}

Describe 'ACP write commands' {
	It 'builds the ACP allowlist and creates the policy' {
		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\New-PpacTenantAcpPolicy -Name 'ACP New' -ConnectorId 'shared_office365', '/providers/Microsoft.PowerApps/apis/shared_sql' -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Post'
		$call.Body | Should -Match 'ConnectorManagement'
		$call.Body | Should -Match '/providers/Microsoft.PowerApps/apis/shared_office365'
		$call.Body | Should -Match '/providers/Microsoft.PowerApps/apis/shared_sql'
	}

	It 'replaces the ACP allowlist on update' {
		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\Set-PpacTenantAcpPolicy -PolicyId '11111111-1111-1111-1111-111111111111' -ConnectorId 'shared_sql' -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Put'
		$call.Body | Should -Match '/providers/Microsoft.PowerApps/apis/shared_sql'
		$call.Body | Should -Not -Match 'shared_office365'
	}

	It 'delegates ACP assignments to the general assignment commands' {
		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\Add-PpacEnvironmentAcpPolicyAssignment -EnvironmentId 'es-ude-motz-01' -PolicyId '11111111-1111-1111-1111-111111111111' -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Uri | Should -Match '/environments/af6c129c-c893-e544-8b42-e38a584ba34c/assignments'

		& (Get-Module PpacGovernanceWriteFixture) { $script:calls = @() }
		$null = PpacGovernanceWriteFixture\Add-PpacEnvironmentGroupAcpPolicyAssignment -EnvironmentGroupId 'group-1' -PolicyId '11111111-1111-1111-1111-111111111111' -Confirm:$false
		$call = & (Get-Module PpacGovernanceWriteFixture) { $script:calls[-1] }
		$call.Uri | Should -Match '/environmentGroups/group-1/assignments'
	}
}
