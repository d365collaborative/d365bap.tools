<#
    Central identity lookup for the active auth provider.

    Get-BapContext collapses the provider branching (AzAccount via Az.Accounts,
    AzCli via the Azure CLI) behind a single call that returns the current
    sign-in as a full object, so cmdlets no longer inline Get-AzContext /
    az account show handling.
#>

function Get-BapContext {
    <#
        .SYNOPSIS
            Gets the current Azure sign-in as a full context object.

        .DESCRIPTION
            Returns the current Azure context for the active auth provider
            ('d365bap.tools.auth.provider', default 'AzAccount') as an object with
            TenantId, TenantName, Upn and UserId properties.

            TenantId and Upn resolve from the plain sign-in state on both providers.
            TenantName and UserId are best-effort: TenantName falls back to an empty
            string when tenant metadata cannot be read, and UserId needs Microsoft
            Graph access in AzCli mode ('az ad signed-in-user show'), so it stays
            empty when Graph is unavailable. Pass -RequireUserId when the caller
            cannot proceed without the Entra object id.

            The call fails fast with an actionable message only when no usable
            sign-in exists at all (i.e. the user is logged out).

        .PARAMETER RequireUserId
            Fail fast with a Graph-access hint when the Entra user id cannot be
            determined, instead of returning an object with an empty UserId.

        .EXAMPLE
            PS C:\> $tenantId = (Get-BapContext).TenantId

            Returns the current tenant id or stops with an actionable message when logged out.

        .NOTES
            Author: Motz Jensen (@Splaxi)
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [switch] $RequireUserId
    )

    $authProvider = Get-PSFConfigValue -FullName 'd365bap.tools.auth.provider' -Fallback 'AzAccount'

    $tenantId = $null
    $tenantName = ''
    $upn = $null
    $userId = ''

    if ($authProvider -eq 'AzCli') {
        try {
            $azShow = az account show --query '{tenant:tenantId, user:user.name}' -o json 2>$null
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace("$azShow")) {
                $azContext = "$azShow" | ConvertFrom-Json -ErrorAction Stop
                if ($null -ne $azContext -and -not [string]::IsNullOrWhiteSpace("$($azContext.tenant)")) {
                    $tenantId = "$($azContext.tenant)".Trim()
                }
                if ($null -ne $azContext -and -not [string]::IsNullOrWhiteSpace("$($azContext.user)")) {
                    $upn = "$($azContext.user)".Trim()
                }
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "az account show failed with: $($_.Exception.Message)"
        }

        if (-not [string]::IsNullOrWhiteSpace("$tenantId")) {
            try {
                $rawNames = az account tenant list --query "[?tenantId=='$tenantId'].displayName" -o tsv 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $firstName = @($rawNames | Where-Object { -not [string]::IsNullOrWhiteSpace("$_") }) | Select-Object -First 1
                    if ($null -ne $firstName) {
                        $tenantName = "$firstName".Trim()
                    }
                }
            }
            catch {
                Write-PSFMessage -Level Verbose -Message "az account tenant list failed with: $($_.Exception.Message)"
            }

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
    }
    else {
        try {
            $azContext = Get-AzContext -ErrorAction Stop
            if ($null -ne $azContext) {
                if ($null -ne $azContext.Tenant -and -not [string]::IsNullOrWhiteSpace("$($azContext.Tenant.Id)")) {
                    $tenantId = "$($azContext.Tenant.Id)".Trim()
                }
                if ($null -ne $azContext.Account -and -not [string]::IsNullOrWhiteSpace("$($azContext.Account.Id)")) {
                    $upn = "$($azContext.Account.Id)".Trim()
                }
                if ($null -ne $azContext.Account -and $null -ne $azContext.Account.ExtendedProperties) {
                    $extObj = $azContext.Account.ExtendedProperties
                    if (-not [string]::IsNullOrWhiteSpace("$($extObj.HomeAccountId)")) {
                        $userId = "$($extObj.HomeAccountId)".Replace(".$($extObj.Tenants)", "")
                    }
                }
            }
        }
        catch {
            Write-PSFMessage -Level Verbose -Message "Get-AzContext failed with: $($_.Exception.Message)"
        }

        if (-not [string]::IsNullOrWhiteSpace("$tenantId")) {
            try {
                $azTenant = Get-AzTenant -ErrorAction Stop | Where-Object { $_.Id -eq $tenantId } | Select-Object -First 1
                if ($null -ne $azTenant -and -not [string]::IsNullOrWhiteSpace("$($azTenant.Name)")) {
                    $tenantName = "$($azTenant.Name)".Trim()
                }
            }
            catch {
                Write-PSFMessage -Level Verbose -Message "Get-AzTenant failed with: $($_.Exception.Message)"
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace("$tenantId") -or [string]::IsNullOrWhiteSpace("$upn")) {
        $messageString = "Unable to determine the current Azure sign-in. Please run <c='em'>Connect-AzAccount</c> or <c='em'>az login</c> and try again."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the current Azure sign-in could not be determined." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    if ($RequireUserId -and [string]::IsNullOrWhiteSpace("$userId")) {
        $messageString = "Unable to determine the current Entra user id. Please run <c='em'>Connect-AzAccount</c>, or <c='em'>az login</c> with a user account that has Microsoft Graph access, and try again."
        Write-PSFMessage -Level Important -Message $messageString
        Stop-PSFFunction -Message "Stopping because the current Entra user id could not be determined." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
        return
    }

    $context = [PSCustomObject]@{
        TenantId   = "$tenantId"
        TenantName = "$tenantName"
        Upn        = "$upn"
        UserId     = "$userId"
    }
    $context.PSObject.TypeNames.Insert(0, 'D365Bap.Tools.CurrentContext')
    return $context
}
