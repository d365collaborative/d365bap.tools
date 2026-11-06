function Start-BapRbacRolePreload {
	<#
    .SYNOPSIS
        Refreshes role definitions in the background.

    .DESCRIPTION
        Keeps the bundled fallback usable while refreshing the user catalog at most daily.

    .EXAMPLE
        PS C:\> Start-BapRbacRolePreload

        Starts a best-effort background refresh when needed.
    #>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Refreshes a local discovery cache.')]
	[CmdletBinding()]
	[OutputType([void])]
	param ()

	try {
		$cachePath = Get-BapRbacRoleCachePath
		$cacheFile = Get-Item -LiteralPath $cachePath `
			-ErrorAction SilentlyContinue

		if ((-not ($null -eq $cacheFile)) `
				-and ($cacheFile.LastWriteTimeUtc -gt [datetime]::UtcNow.AddHours(-24))) { return }

		$jobName = 'd365bap.tools.rbac.roles.preload'
		$running = Get-Job -Name $jobName `
			-ErrorAction SilentlyContinue |
		Where-Object State -in @('Running', 'NotStarted')

		if ($running) { return }
		Get-Job -Name $jobName `
			-ErrorAction SilentlyContinue |
		Remove-Job -Force `
			-ErrorAction SilentlyContinue

		$provider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' `
			-Fallback 'AzAccount'

		$catalogSource = Join-Path $script:ModuleRoot 'internal/functions/RbacRoleCatalog.ps1'
		$apiVersion = $script:BapApiVersions.PowerPlatform
		Start-Job -Name $jobName `
			-ScriptBlock {
			try {
				. $using:catalogSource
				if ($using:provider -eq 'AzCli') {
					$raw = & az account get-access-token --resource 'https://api.powerplatform.com' --query accessToken -o tsv 2>$null
					if ($LASTEXITCODE -ne 0) { return }
					if ([string]::IsNullOrWhiteSpace($raw)) { return }
					$token = "$raw".Trim()
				}
				else {
					Import-Module Az.Accounts -ErrorAction Stop
					if (-not (Get-AzContext -ErrorAction SilentlyContinue)) { return }
					$result = Get-AzAccessToken -ResourceUrl 'https://api.powerplatform.com' `
						-ErrorAction Stop

					$token = if ($result.Token -is [securestring]) {
						[Net.NetworkCredential]::new('', $result.Token).Password
					}
					else {
						$result.Token
					}
				}
				$uri = 'https://api.powerplatform.com/authorization/roleDefinitions?api-version={0}' `
					-f $using:apiVersion

				$hashHeaders = @{ Authorization = "Bearer $token" }
				$response = Invoke-RestMethod -Method Get `
					-Uri $uri `
					-Headers $hashHeaders `
					-ConnectionTimeoutSeconds 30 `
					-OperationTimeoutSeconds 30 `
					-ErrorAction Stop

				Save-BapRbacRoleCatalog -Roles @($response.value)
			}
			catch { Write-Verbose -Message 'Role catalog refresh unavailable.' }
		} > $null
	}
	catch {
		Write-PSFMessage -Level Verbose `
			-Message 'Role catalog preload skipped.'
	}

}

Start-BapRbacRolePreload
