
<#
    .SYNOPSIS
        Get members of PPAC RBAC roles in the tenant.
        
    .DESCRIPTION
        Gets members of PPAC RBAC roles in the tenant. This command is used to retrieve the list of service principals that are assigned to PPAC RBAC roles in Power Platform.
        
    .PARAMETER ServicePrincipalId
        The object id of the service principal to filter by.
        
        You can use wildcards (*) for partial matches. If not specified, members of all service principals will be returned.
        
    .PARAMETER Role
        The name, id or description of the PPAC RBAC role to filter by.
        
        You can use wildcards (*) for partial matches. If not specified, members of all roles will be returned.
        
    .PARAMETER AsExcelOutput
        Instructs the command to output the results to an Excel file instead of the console.
        
    .EXAMPLE
        PS C:\> Get-PpacRbacRoleMember -Role "*admin*"
        
        This command retrieves all members of PPAC RBAC roles with names or descriptions containing "admin".
        
    .EXAMPLE
        PS C:\> Get-PpacRbacRoleMember -ServicePrincipalId "00000000-0000-0000-0000-000000000000" -AsExcelOutput
        
        This command retrieves all PPAC RBAC role assignments for the service principal with object id "00000000-0000-0000-0000-000000000000".
        The results will be exported to an Excel file instead of being displayed in the console.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        
        Based on:
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-tutorial-rbac-role-assignment?tabs=PowerShell
        https://learn.microsoft.com/en-us/power-platform/admin/programmability-authentication-v2?tabs=powershell%2Cpowershell-interactive%2Cpowershell-confidential
#>
function Get-PpacRbacRoleMember {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    param (
        [string] $ServicePrincipalId = "*",

        [string] $Role = "*",

        [switch] $AsExcelOutput
    )
    
    begin {
        $token = Get-PSFConfigValue -FullName "d365bap.tools.internal.ppac.rbac.token"

        if ($null -eq $token) {
            Write-PSFMessage -Level Warning -Message "No authentication token found for PPAC RBAC operations. Please run <c='em'>Set-PpacRbacContext</c> to authenticate first."
            Stop-PSFFunction -Message "Stopping because of missing authentication token." -Exception $([System.Exception]::new("Missing authentication token for PPAC RBAC operations."))
            return
        }

        $headersPowerApi = @{ 'Content-Type' = 'application/json' }
        $headersPowerApi.Add('Authorization', $token)

        $pathMisc = Get-PSFConfigValue -FullName "d365bap.tools.internal.misc.path"
            
        $rbacRoles = Get-Content `
            -Path "$pathMisc\Ppac.Rbac.Roles.json" `
            -Raw | ConvertFrom-Json

        if ($role -eq "*") {
            $roleId = "*"
        }
        else {
            $roleId = $rbacRoles | `
                Where-Object { $_.roleDefinitionName -eq $Role } | `
                Select-Object -First 1 -ExpandProperty roleDefinitionId

            if ($null -eq $roleId) {
                $messageString = "The specified role: <c='em'>$Role</c> was not found. Please provide a valid role name. Try running the command <c='em'>Get-PpacRbacRole</c> to see the list of valid role names."
                Write-PSFMessage -Level Important -Message $MessageString
                Stop-PSFFunction -Message "Stopping because of invalid role name." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resColRaw = Invoke-RestMethod `
            -Method Get `
            -Uri "https://api.powerplatform.com/authorization/roleAssignments?api-version=2024-10-01" `
            -Headers $headersPowerApi 4> $null | `
            Select-Object -ExpandProperty value

        $resCol = $resColRaw | Where-Object {
            ($_.principalObjectId -like $ServicePrincipalId) -and
            ($_.roleDefinitionId -like $roleId)
        } | Select-PSFObject -TypeName "D365Bap.Tools.PpacRbacRoleAssignment" `
            -ExcludeProperty "@odata.etag" `
            -Property "principalObjectId as ServicePrincipalId",
        "roleDefinitionId as RoleId",
        @{Name = "Role"; Expression = { $tmpRoleId = $_.roleDefinitionId;
                $rbacRoles | Where-Object {
                    $_.roleDefinitionId -eq $tmpRoleId
                } | Select-Object -First 1 -ExpandProperty roleDefinitionName
            }
        },
        *

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacRbacRoleMember"
            return
        }

        $resCol
    }

    end {
        
    }
    
}