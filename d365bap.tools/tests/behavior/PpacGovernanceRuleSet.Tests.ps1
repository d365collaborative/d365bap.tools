BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacGovernanceRuleSetFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'functions/Remove-PpacTenantRuleBasedPolicyRuleSet.ps1')
		. (Join-Path $Root 'functions/Remove-PpacTenantAcpPolicyRuleSet.ps1')
		function Test-PSFFunctionInterrupt { $false }
		function Stop-PSFFunction {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test fixture.')]
			param($Message, $Exception, $ErrorRecord)
			$null = $Exception
			$null = $ErrorRecord
			throw $Message
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
		$script:calls = @()
		function Invoke-RestMethod {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Test fixture.')]
			param($Method, $Uri, $Headers, $Body, $ContentType)
			$null = $Headers
			$null = $ContentType
			$script:calls += [pscustomobject]@{ Method = $Method; Uri = $Uri; Body = $Body }
			[pscustomobject]@{}
		}
		$script:policy = [pscustomobject]@{
			PolicyId = '11111111-1111-1111-1111-111111111111'
			Name     = 'ACP Baseline'
		}
		function Get-PpacTenantRuleBasedPolicy { param($PolicyId) $script:policy }
		function Get-PpacTenantAcpPolicy { param($PolicyId) $script:policy }
		Export-ModuleMember -Function Remove-PpacTenantRuleBasedPolicyRuleSet, Remove-PpacTenantAcpPolicyRuleSet
	}
	Import-Module $fixture -Force
}

Describe 'Governance rule set removal' {
	It 'removes the supplied rule set' {
		& (Get-Module PpacGovernanceRuleSetFixture) { $script:calls = @() }
		$null = PpacGovernanceRuleSetFixture\Remove-PpacTenantRuleBasedPolicyRuleSet -PolicyId '11111111-1111-1111-1111-111111111111' -RuleSetId 'ConnectorManagement' -Confirm:$false
		$call = & (Get-Module PpacGovernanceRuleSetFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Patch'
		$call.Uri | Should -Match '/removeRule\?api-version=2024-10-01'
		$call.Body | Should -Match 'ConnectorManagement'
	}

	It 'removes the ACP rule set through the general command' {
		& (Get-Module PpacGovernanceRuleSetFixture) { $script:calls = @() }
		$null = PpacGovernanceRuleSetFixture\Remove-PpacTenantAcpPolicyRuleSet -PolicyId '11111111-1111-1111-1111-111111111111' -Confirm:$false
		$call = & (Get-Module PpacGovernanceRuleSetFixture) { $script:calls[-1] }
		$call.Uri | Should -Match '/removeRule\?api-version=2024-10-01'
		$call.Body | Should -Match 'ConnectorManagement'
	}
}
