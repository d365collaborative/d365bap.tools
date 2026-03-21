
<#
    .SYNOPSIS
        Add a service principal as a member of a PPAC RBAC role in a specific scope.
        
    .DESCRIPTION
        Adds a service principal as a member of a PPAC RBAC role in a specific scope. This command is used to grant permissions to service principals in Power Platform.
        
        The role assignment will be created in the tenant's root scope, but the specified scope will be used for permission evaluation.
        
    .PARAMETER ServicePrincipalId
        The object id of the service principal to which the role will be assigned.
        
    .PARAMETER Role
        The name of the PPAC RBAC role to which the service principal will be assigned. Use the command <c='em'>Get-PpacRbacRole</c> to see the list of valid role names.
        
    .PARAMETER Scope
        The scope in which the role assignment will be evaluated.
        
        Will be auto-populated based on the role. Anything beyond /tenants/{0} needs to be filled out by the user.
        
        For example, if the scope is /tenants/{0}/environments/{1}, the user needs to fill out the {1} (environmentId).
        
    .EXAMPLE
        PS C:\> Add-PpacRbacRoleMember -ServicePrincipalId "00000000-0000-0000-0000-000000000000" -Role "Power Platform Owner" -Scope "/tenants/{0}"
        
        This command assigns the service principal with object id "00000000-0000-0000-0000-000000000000" to the "Power Platform Owner" role in the tenant scope.
        The service principal will have owner permissions across all Power Platform environments in the tenant.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        
        Based on:
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Add-PpacRbacRoleMember {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ServicePrincipalId,

        [Parameter(Mandatory = $true)]
        [string] $Role,

        [Parameter(Mandatory = $true)]
        [string] $Scope
    )
    
    begin {
        # We need to translate the role name to roleDefinitionId.
        $pathMisc = Get-PSFConfigValue -FullName "d365bap.tools.internal.misc.path"

        $rbacRoles = Get-Content `
            -Path "$pathMisc\Ppac.Rbac.Roles.json" `
            -Raw | ConvertFrom-Json

        $roleDefinitionId = $rbacRoles | `
            Where-Object { $_.roleDefinitionName -eq $Role } | `
            Select-Object -First 1 -ExpandProperty roleDefinitionId
    
        if ($null -eq $roleDefinitionId) {
            $messageString = "The specified role: <c='em'>$Role</c> was not found. Please provide a valid role name. Try running the command <c='em'>Get-PpacRbacRole</c> to see the list of valid role names."
            Write-PSFMessage -Level Important -Message $MessageString
            Stop-PSFFunction -Message "Stopping because of invalid role name." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    
        $token = Get-PSFConfigValue -FullName "d365bap.tools.internal.ppac.rbac.token"

        if ($null -eq $token) {
            Write-PSFMessage -Level Warning -Message "No authentication token found for PPAC RBAC operations. Please run <c='em'>Set-PpacRbacContext</c> to authenticate first."
            Stop-PSFFunction -Message "Stopping because of missing authentication token." -Exception $([System.Exception]::new("Missing authentication token for PPAC RBAC operations."))
            return
        }

        $headersPowerApi = @{ 'Content-Type' = 'application/json' }
        $headersPowerApi.Add('Authorization', $token)

        $tenantId = (Get-AzContext).Tenant.Id
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $tmpScope = $Scope.Replace('/tenants/{0}', "/tenants/$tenantId")

        if ($tmpScope -like "*{*}*") {
            $tmpText = $tmpScope.Replace('{', "<c='em'>--").Replace('}', "--</c>")
            $messageString = "The specified scope: '$tmpText' is not valid. You need to fill out the missing scope details."
            Write-PSFMessage -Level Important -Message $MessageString
            Stop-PSFFunction -Message "Stopping because of invalid scope." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $resTmp = Get-PpacRbacRoleMember `
            -ServicePrincipalId $ServicePrincipalId `
            -Role $Role

        if (-not ($null -eq $resTmp)) {
            $resTmp
            return
        }

        $payload = @{
            roleDefinitionId  = $roleDefinitionId
            principalObjectId = $ServicePrincipalId
            principalType     = "ApplicationUser"
            scope             = $tmpScope
        } | ConvertTo-Json

        Invoke-RestMethod -Method Post `
            -Uri "https://api.powerplatform.com/authorization/roleAssignments?api-version=2024-10-01" `
            -Headers $headersPowerApi `
            -ContentType $headersPowerApi.'Content-Type' `
            -Body $payload `
            -StatusCodeVariable statusAssign > $null 4> $null

        if (-not ($statusAssign -like "2*")) {
            $messageString = "Failed to assign the role to the service principal. Verify that the service principal exists and the scope is correct. Try running the command <c='em'>Get-PpacRbacRoleMember</c> to see existing role assignments for service principals."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because assigning the role to the service principal in the Power Platform environment failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Get-PpacRbacRoleMember `
            -ServicePrincipalId $ServicePrincipalId `
            -Role $Role
    }

    end {
        
    }
    
}