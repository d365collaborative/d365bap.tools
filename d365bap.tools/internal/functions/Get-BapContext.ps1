function Get-BapContext {
	<#
        .SYNOPSIS
            Gets the current Azure sign-in as a full context object.

        .DESCRIPTION
            Returns tenant and account details from the selected provider.
            UserId is resolved only for user accounts. App sessions skip user-only
            lookups. Tenant metadata and user Graph lookup are best-effort.

        .PARAMETER RequireUserId
            Stops when the current sign-in has no Entra user id.

        .PARAMETER AllowEmpty
            Returns $null instead of stopping when no usable sign-in exists.

        .EXAMPLE
            PS C:\> $tenantId = (Get-BapContext).TenantId

            Returns the current tenant id or stops with an actionable message when logged out.

        .EXAMPLE
            PS C:\> Get-BapContext -RequireUserId

            Returns a user context or stops when the user id cannot be determined.
            It uses -RequireUserId to require a human user identity.

        .EXAMPLE
            PS C:\> Get-BapContext -AllowEmpty

            Returns the current context or no output when logged out.
            It uses -AllowEmpty to permit a missing sign-in.

        .NOTES
            Author: Motz Jensen (@Splaxi)
    #>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[switch] $RequireUserId,

		[switch] $AllowEmpty
	)

	$authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' `
		-Fallback 'AzAccount'

	$tenantId = $null
	$tenantName = ''
	$upn = $null
	$userId = ''
	$isUser = $false

	if ($authProvider -eq 'AzCli') {
		try {
			$azShow = az account show --query '{tenant:tenantId, user:user.name, userType:user.type}' -o json 2>$null
			if (($LASTEXITCODE -eq 0) `
					-and (-not [string]::IsNullOrWhiteSpace($azShow))) {
				$azContext = "$azShow" |
				ConvertFrom-Json -ErrorAction Stop
				$isUser = $azContext.userType -eq 'user'
				if ((-not ($null -eq $azContext)) `
						-and (-not [string]::IsNullOrWhiteSpace($azContext.tenant))) {
					$tenantId = "$($azContext.tenant)".Trim()
				}
				if ((-not ($null -eq $azContext)) `
						-and (-not [string]::IsNullOrWhiteSpace($azContext.user))) {
					$upn = "$($azContext.user)".Trim()
				}
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "az account show failed with: $($_.Exception.Message)"
		}

		if (-not [string]::IsNullOrWhiteSpace($tenantId)) {
			try {
				$rawNames = az account tenant list --query "[?tenantId=='$tenantId'].displayName" -o tsv 2>$null
				if ($LASTEXITCODE -eq 0) {
					$objFirstName = @(
						$rawNames |
						Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
					) |
					Select-Object -First 1

					if (-not ($null -eq $objFirstName)) {
						$tenantName = "$objFirstName".Trim()
					}
				}
			}
			catch {
				Write-PSFMessage -Level Verbose `
					-Message "az account tenant list failed with: $($_.Exception.Message)"
			}

			if ($isUser) {
				try {
					$azUserId = az ad signed-in-user show --query id -o tsv 2>$null
					if (($LASTEXITCODE -eq 0) `
							-and (-not [string]::IsNullOrWhiteSpace($azUserId))) {
						$userId = "$azUserId".Trim()
					}
				}
				catch {
					Write-PSFMessage -Level Verbose `
						-Message "az ad signed-in-user show failed with: $($_.Exception.Message)"
				}
			}
		}
	}
	else {
		try {
			$azContext = Get-AzContext -ErrorAction Stop
			if (-not ($null -eq $azContext)) {
				$isUser = $azContext.Account.Type -eq 'User'
				if ((-not ($null -eq $azContext.Tenant)) `
						-and (-not [string]::IsNullOrWhiteSpace($azContext.Tenant.Id))) {
					$tenantId = "$($azContext.Tenant.Id)".Trim()
				}
				if ((-not ($null -eq $azContext.Account)) `
						-and (-not [string]::IsNullOrWhiteSpace($azContext.Account.Id))) {
					$upn = "$($azContext.Account.Id)".Trim()
				}
				if (($isUser) `
						-and (-not ($null -eq $azContext.Account.ExtendedProperties))) {
					$extObj = $azContext.Account.ExtendedProperties
					if (-not [string]::IsNullOrWhiteSpace($extObj.HomeAccountId)) {
						$userId = "$($extObj.HomeAccountId)".Replace(".$($extObj.Tenants)", "")
					}
				}
			}
		}
		catch {
			Write-PSFMessage -Level Verbose `
				-Message "Get-AzContext failed with: $($_.Exception.Message)"
		}

		if (-not [string]::IsNullOrWhiteSpace($tenantId)) {
			try {
				$objAzTenant = Get-AzTenant -ErrorAction Stop |
				Where-Object { $_.Id -eq $tenantId } |
				Select-Object -First 1
				if ((-not ($null -eq $objAzTenant)) `
						-and (-not [string]::IsNullOrWhiteSpace($objAzTenant.Name))) {
					$tenantName = "$($objAzTenant.Name)".Trim()
				}
			}
			catch {
				Write-PSFMessage -Level Verbose `
					-Message "Get-AzTenant failed with: $($_.Exception.Message)"
			}
		}
	}

	if (([string]::IsNullOrWhiteSpace($tenantId)) `
			-or ([string]::IsNullOrWhiteSpace($upn))) {
		if ($AllowEmpty) {
			$null
			return
		}
		$messageString = "Unable to determine the current Azure sign-in. Please run <c='em'>Connect-AzAccount</c> or <c='em'>az login</c> and try again."
		Write-PSFMessage -Level Important `
			-Message $messageString

		Stop-PSFFunction -Message "Stopping because the current Azure sign-in could not be determined." `
			-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) `
			-StepsUpward 1

		return
	}

	if (($RequireUserId) `
			-and ([string]::IsNullOrWhiteSpace($userId))) {
		if ($isUser) {
			$messageString = "Unable to determine the current Entra user id. Please run <c='em'>Connect-AzAccount</c>, or <c='em'>az login</c> with a user account that has Microsoft Graph access, and try again."
		}
		else {
			$messageString = "This operation requires an Entra user identity. Please run <c='em'>Connect-AzAccount</c> or <c='em'>az login</c> with a user account and try again."
		}
		Write-PSFMessage -Level Important `
			-Message $messageString

		Stop-PSFFunction -Message "Stopping because the current Entra user id could not be determined." `
			-Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) `
			-StepsUpward 1

		return
	}

	$objContext = [PSCustomObject][ordered]@{
		TenantId   = "$tenantId"
		TenantName = "$tenantName"
		Upn        = "$upn"
		UserId     = "$userId"
	}
	$objContext.PSObject.TypeNames.Insert(0, 'D365Bap.Tools.CurrentContext')
	$objContext
}
