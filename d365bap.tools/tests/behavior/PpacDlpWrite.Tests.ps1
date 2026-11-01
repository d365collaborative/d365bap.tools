BeforeAll {
	Import-Module PSFramework -ErrorAction Stop
	$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
	$fixture = New-Module -Name PpacDlpWriteFixture -ArgumentList $sourceRoot -ScriptBlock {
		param($Root)
		. (Join-Path $Root 'internal/functions/Get-PpacEnvironmentDlpRoute.ps1')
		. (Join-Path $Root 'functions/New-PpacTenantDlpPolicy.ps1')
		. (Join-Path $Root 'functions/New-PpacEnvironmentDlpPolicy.ps1')
		. (Join-Path $Root 'functions/Set-PpacTenantDlpPolicy.ps1')
		. (Join-Path $Root 'functions/Set-PpacEnvironmentDlpPolicy.ps1')
		. (Join-Path $Root 'functions/Remove-PpacTenantDlpPolicy.ps1')
		. (Join-Path $Root 'functions/Remove-PpacEnvironmentDlpPolicy.ps1')
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
			param($ResourceUrl, [switch] $Bap)
			$null = $ResourceUrl
			$null = $Bap
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
			if ($Method -eq 'Post') { return [pscustomobject]@{ name = 'new-policy'; displayName = 'New policy' } }
			[pscustomobject]@{}
		}
		$script:policy = [pscustomobject]@{
			PolicyId    = '11111111-1111-1111-1111-111111111111'
			Name        = 'Existing policy'
			PolicyScope = 'Tenant'
		}
		function Get-PpacTenantDlpPolicy { param($PolicyId) $null = $PolicyId; $script:policy }
		function Get-PpacEnvironmentDlpPolicy { param($EnvironmentId, $PolicyId) $null = $EnvironmentId; $null = $PolicyId; $script:policy }
		Export-ModuleMember -Function New-PpacTenantDlpPolicy, New-PpacEnvironmentDlpPolicy, Set-PpacTenantDlpPolicy, Set-PpacEnvironmentDlpPolicy, Remove-PpacTenantDlpPolicy, Remove-PpacEnvironmentDlpPolicy
	}
	Import-Module $fixture -Force
}

Describe 'Classic DLP write commands' {
	It 'creates tenant and environment policies with POST' {
		& (Get-Module PpacDlpWriteFixture) { $script:calls = @() }
		$null = PpacDlpWriteFixture\New-PpacTenantDlpPolicy -Policy @{ displayName = 'Tenant'; environmentType = 'AllEnvironments' } -Confirm:$false
		$call = & (Get-Module PpacDlpWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Post'
		$call.Uri | Should -Match 'scopes/admin/apiPolicies\?api-version=2018-10-01'
		$call.Body | Should -Match 'AllEnvironments'

		& (Get-Module PpacDlpWriteFixture) { $script:calls = @() }
		$null = PpacDlpWriteFixture\New-PpacEnvironmentDlpPolicy -EnvironmentId 'es-ude-motz-01' -Policy @{ displayName = 'Environment'; environmentType = 'SingleEnvironment' } -Confirm:$false
		$call = & (Get-Module PpacDlpWriteFixture) { $script:calls[-1] }
		$call.Uri | Should -Match 'scopes/admin/environments/af6c129c-c893-e544-8b42-e38a584ba34c/apiPolicies'
	}

	It 'updates tenant and environment policies' {
		& (Get-Module PpacDlpWriteFixture) { $script:calls = @() }
		$null = PpacDlpWriteFixture\Set-PpacTenantDlpPolicy -PolicyId '11111111-1111-1111-1111-111111111111' -Policy @{ displayName = 'Updated' } -Confirm:$false
		$call = & (Get-Module PpacDlpWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Put'

		& (Get-Module PpacDlpWriteFixture) { $script:calls = @() }
		$null = PpacDlpWriteFixture\Set-PpacEnvironmentDlpPolicy -EnvironmentId 'es-ude-motz-01' -PolicyId '11111111-1111-1111-1111-111111111111' -Policy @{ displayName = 'Updated' } -Confirm:$false
		$call = & (Get-Module PpacDlpWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Patch'
		$call.Uri | Should -Match 'scopes/admin/environments/af6c129c-c893-e544-8b42-e38a584ba34c/apiPolicies/11111111-1111-1111-1111-111111111111'
	}

	It 'deletes tenant and environment policies' {
		& (Get-Module PpacDlpWriteFixture) { $script:calls = @() }
		$null = PpacDlpWriteFixture\Remove-PpacTenantDlpPolicy -PolicyId '11111111-1111-1111-1111-111111111111' -Confirm:$false
		$call = & (Get-Module PpacDlpWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Delete'
		$call.Uri | Should -Match 'scopes/admin/apiPolicies/11111111-1111-1111-1111-111111111111'

		& (Get-Module PpacDlpWriteFixture) { $script:calls = @() }
		$null = PpacDlpWriteFixture\Remove-PpacEnvironmentDlpPolicy -EnvironmentId 'es-ude-motz-01' -PolicyId '11111111-1111-1111-1111-111111111111' -Confirm:$false
		$call = & (Get-Module PpacDlpWriteFixture) { $script:calls[-1] }
		$call.Method | Should -Be 'Delete'
		$call.Uri | Should -Match 'scopes/admin/environments/af6c129c-c893-e544-8b42-e38a584ba34c/apiPolicies/11111111-1111-1111-1111-111111111111'
	}
}
