Describe 'Unified environment deprecation notices with <Loading> imports' -ForEach @(
	@{ Loading = 'Files' }
	@{ Loading = 'ScriptBlocks' }
) {
	BeforeAll {
		$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
		$fixture = New-Module -Name "UnifiedNotice$Loading" -ArgumentList $sourceRoot, $Loading -ScriptBlock {
			param($Root, $Loading)
			foreach ($itemSource in @('functions/Get-UnifiedEnvironment.ps1', 'internal/functions/Get-Environment.ps1')) {
				$tmpPath = Join-Path $Root $itemSource
				if ($Loading -eq 'Files') {
					. $tmpPath
				}
				else {
					$ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create([IO.File]::ReadAllText($tmpPath)), $null, $null)
				}
			}
			$script:notices = @()
			function Write-BapDeprecationNotice {
				param($Key)
				$script:notices += $Key
			}
			function Get-BapEnvironment { param($EnvironmentId, [switch] $FscmEnabled) @() }
			function Test-Guid { param($InputObject) $false }
			function Write-PSFMessage { param($Level, $Message) }
			function Stop-PSFFunction { param($Message, $Exception, $EnableException) throw 'No environments in fixture' }
			function Invoke-LegacyEnvironmentLookup { Get-UnifiedEnvironment -SkipVersionDetails }
			function Invoke-CentralEnvironmentLookup {
				param([switch] $VersionDetails)
				Get-Environment -Unified -VersionDetails:$VersionDetails
			}
			Export-ModuleMember -Function Get-UnifiedEnvironment, Invoke-LegacyEnvironmentLookup, Invoke-CentralEnvironmentLookup
		}
		Import-Module $fixture -Force
		$direct = Get-Command "$($fixture.Name)\Get-UnifiedEnvironment"
		$legacy = Get-Command "$($fixture.Name)\Invoke-LegacyEnvironmentLookup"
		$central = Get-Command "$($fixture.Name)\Invoke-CentralEnvironmentLookup"
	}

	BeforeEach {
		& $fixture { $script:notices = @() }
	}

	AfterAll {
		Remove-Module $fixture -Force
	}

	It 'announces the deprecated parameter when called directly' {
		$null = & $direct -SkipVersionDetails
		@(& $fixture { $script:notices }) | Should -Be @('Get-UnifiedEnvironment.SkipVersionDetails')
	}

	It 'keeps direct calls without the deprecated parameter quiet' {
		$null = & $direct
		@(& $fixture { $script:notices }).Count | Should -Be 0
	}

	It 'keeps other module commands quiet when they use the deprecated parameter internally' {
		$null = & $legacy
		@(& $fixture { $script:notices }).Count | Should -Be 0
	}

	It 'keeps the central environment lookup quiet with and without version details' {
		{ & $central } | Should -Throw '*No environments in fixture*'
		{ & $central -VersionDetails } | Should -Throw '*No environments in fixture*'
		@(& $fixture { $script:notices }).Count | Should -Be 0
	}
}
