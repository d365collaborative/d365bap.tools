<#
    Central identity lookups for the active auth provider.

    These helpers collapse the provider branching (AzAccount via Az.Accounts,
    AzCli via the Azure CLI) behind single calls, so cmdlets no longer inline
    Get-AzContext / az account show handling. All three fail fast with an
    actionable message when the current identity cannot be determined.
#>

function Get-BapTenantId {
    <#
        .SYNOPSIS
            Gets the current Azure tenant id for the active auth provider.

        .DESCRIPTION
            Returns the tenant id of the current Azure context: (Get-AzContext).Tenant.Id
            when the auth provider is 'AzAccount', or the tenant from
            'az account show' when it is 'AzCli'.

        .EXAMPLE
            PS C:\> $tenantId = Get-BapTenantId

            Returns the current tenant id or stops with an actionable message when logged out.

        .NOTES
            Author: Motz Jensen (@Splaxi)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

    $tenantId = $null
    if ($authProvider -eq 'AzCli') {
        try {
            $azTenant = az account show --query tenantId -o tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$azTenant")) {
                $tenantId = "$azTenant".Trim()
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "az account show failed with: $($_.Exception.Message)"
        }
    }
    else {
        try {
            $tenantId = (Get-AzContext -ErrorAction Stop).Tenant.Id
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Get-AzContext failed with: $($_.Exception.Message)"
        }
    }

    if ([string]::IsNullOrWhiteSpace("$tenantId")) {
        $messageString = "Unable to determine the current tenant. Please run <c='em'>Connect-AzAccount</c> or <c='em'>az login</c> and try again."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the current tenant could not be determined." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    return "$tenantId"
}

function Get-BapCurrentUserName {
    <#
        .SYNOPSIS
            Gets the user principal name of the current Azure sign-in.

        .DESCRIPTION
            Returns the UPN of the current Azure account: the Az context Account.Id
            when the auth provider is 'AzAccount', or 'user.name' from
            'az account show' when it is 'AzCli'. No extra Graph permissions needed.

        .EXAMPLE
            PS C:\> $upn = Get-BapCurrentUserName

            Returns the current user's UPN or stops with an actionable message when logged out.

        .NOTES
            Author: Motz Jensen (@Splaxi)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

    $userName = $null
    if ($authProvider -eq 'AzCli') {
        try {
            $azUser = az account show --query user.name -o tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$azUser")) {
                $userName = "$azUser".Trim()
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "az account show failed with: $($_.Exception.Message)"
        }
    }
    else {
        try {
            $userName = (Get-AzContext -ErrorAction Stop).Account.Id
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Get-AzContext failed with: $($_.Exception.Message)"
        }
    }

    if ([string]::IsNullOrWhiteSpace("$userName")) {
        $messageString = "Unable to determine the current user. Please run <c='em'>Connect-AzAccount</c> or <c='em'>az login</c> and try again."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the current user could not be determined." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    return "$userName"
}

function Get-BapCurrentUserId {
    <#
        .SYNOPSIS
            Gets the Microsoft Entra object id of the current Azure sign-in.

        .DESCRIPTION
            Returns the bare Entra user id: the HomeAccountId prefix from the Az context
            account when the auth provider is 'AzAccount', or the id from
            'az ad signed-in-user show' (requires Microsoft Graph access) when it is 'AzCli'.

        .EXAMPLE
            PS C:\> $userId = Get-BapCurrentUserId

            Returns the current user's Entra object id or stops with an actionable message.

        .NOTES
            Author: Motz Jensen (@Splaxi)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param ()

    $authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

    $userId = $null
    if ($authProvider -eq 'AzCli') {
        try {
            $azUserId = az ad signed-in-user show --query id -o tsv 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$azUserId")) {
                $userId = "$azUserId".Trim()
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "az ad signed-in-user show failed with: $($_.Exception.Message)"
        }
    }
    else {
        try {
            $extObj = ((Get-AzContext -ErrorAction Stop) | Select-Object -ExpandProperty account).ExtendedProperties
            $userId = $extObj.HomeAccountId.Replace(".$($extObj.Tenants)", "")
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Get-AzContext failed with: $($_.Exception.Message)"
        }
    }

    if ([string]::IsNullOrWhiteSpace("$userId")) {
        $messageString = "Unable to determine the current Entra user id. Please run <c='em'>Connect-AzAccount</c>, or <c='em'>az login</c> with a user account that has Microsoft Graph access, and try again."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the current Entra user id could not be determined." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    return "$userId"
}
