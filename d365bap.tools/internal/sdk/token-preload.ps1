<#
    Internal runtime for background access token preloading.

    Warms the Azure token cache on module import so the first cmdlet call
    does not pay for sequential token minting. A throttled background job
    mints the static resource set once every 45 minutes; the refreshed
    timestamp is tracked in a user-scoped cache file.

    All failures are Verbose only and never throw, mirroring the
    provisioning discovery refresh in internal/sdk/provisioning.ps1.
#>

$script:BapTokenPreloadResources = @(
	'https://service.powerapps.com/'
	'https://api.powerplatform.com'
	'https://graph.microsoft.com/'
	'065d9450-1e87-434e-ac2f-69af271549ed'
)

function Get-BapTokenPreloadCachePath {
	[CmdletBinding()]
	param ()

	$base = if ($env:APPDATA) { $env:APPDATA } else { Join-Path $HOME '.config' }
	Join-Path (Join-Path $base 'd365bap.tools') 'token-preload.json'
}

function Start-BapTokenPreload {
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseUsingScopeModifierInNewRunspaces", "", Justification = "Start-Job binds values through ArgumentList, the using scope modifier is not supported there.")]
	[CmdletBinding()]
	param (
		[int] $MaxAgeMinutes = 45
	)

	try {
		$azContext = Get-AzContext -ErrorAction SilentlyContinue
		if (-not $azContext) {
			$azCommand = Get-Command az -ErrorAction SilentlyContinue
			$azLoggedIn = $false
			if ($null -ne $azCommand) {
				$previousExitCode = $global:LASTEXITCODE
				try {
					$null = & az account show -o json 2>$null
					if ($LASTEXITCODE -eq 0) { $azLoggedIn = $true }
				}
				finally {
					$global:LASTEXITCODE = $previousExitCode
				}
			}
			if (-not $azLoggedIn) {
				Write-PSFMessage -Level Verbose -Message 'Token preload skipped: no Az login detected.'
				return
			}
		}

		$userPath = Get-BapTokenPreloadCachePath
		if (Test-Path -LiteralPath $userPath) {
			try {
				$state = Get-Content -LiteralPath $userPath -Raw -Encoding utf8 |
				ConvertFrom-Json -AsHashtable -ErrorAction Stop
				if ($state.ContainsKey('refreshedUtc')) {
					$refreshed = [datetime]$state['refreshedUtc']
					if (([datetime]::UtcNow - $refreshed.ToUniversalTime()).TotalMinutes -lt $MaxAgeMinutes) { return }
				}
			}
			catch {
				Write-PSFMessage -Level Verbose -Message "Ignoring unreadable token preload state at $userPath : $($_.Exception.Message)"
			}
		}

		if (Get-Job -Name 'd365bap.tools.token.preload' -State Running -ErrorAction SilentlyContinue) { return }
		Get-Job -Name 'd365bap.tools.token.preload' -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

		# Provider choice cannot be read inside the job: PSFConfig and
		# $script: module state are not shared with the job process, so
		# pass it explicitly and let the job mint fresh tokens.
		$authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

		$null = Start-Job -Name 'd365bap.tools.token.preload' -ScriptBlock {
			param ([string] $CachePath, [string] $AuthProvider, [string] $ModuleRoot, [string[]] $Resources)

			try {
				if ($AuthProvider -eq 'AzAccount') {
					Import-Module Az.Accounts -ErrorAction Stop
					if (-not (Get-AzContext -ErrorAction SilentlyContinue)) { return }
				}

				if (-not (Get-Command Get-BapAccessToken -ErrorAction SilentlyContinue)) {
					$helperPath = Join-Path $ModuleRoot 'internal/functions/Get-BapAccessToken.ps1'
					if (Test-Path -LiteralPath $helperPath) { . $helperPath }
					else { return }
				}

				foreach ($resource in $Resources) {
					try {
						$null = Get-BapAccessToken -ResourceUrl $resource
					}
					catch { Write-PSFMessage -Level Verbose -Message "Token preload: skipping resource '$resource'." }
				}

				# $script:BapTokenCache updated inside Get-BapAccessToken is
				# best-effort here: job state is not shared with the parent
				# session, but minting still warms the provider token cache.
				$null = New-Item -ItemType Directory -Path (Split-Path -Parent $CachePath) -Force -ErrorAction Stop
				@{ refreshedUtc = [datetime]::UtcNow.ToString('o') } |
				ConvertTo-Json -ErrorAction Stop |
				Set-Content -LiteralPath $CachePath -Encoding utf8 -ErrorAction Stop
			}
			catch { Write-PSFMessage -Level Verbose -Message 'Token preload: background probe failed, keeping the previous state.' }
		} -ArgumentList @((Get-BapTokenPreloadCachePath), $authProvider, $script:ModuleRoot, $script:BapTokenPreloadResources)
	}
	catch { Write-PSFMessage -Level Verbose -Message "Token preload was skipped: $($_.Exception.Message)" }
}

Start-BapTokenPreload
