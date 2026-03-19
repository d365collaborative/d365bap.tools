<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER ServicePrincipalId
Parameter description

.PARAMETER Role
Parameter description

.PARAMETER Scope
Parameter description

.EXAMPLE
An example

.NOTES
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