<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Role
Parameter description

.PARAMETER AsExcelOutput
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-PpacRbacRole {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    param (
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
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $resColRaw = Invoke-RestMethod `
            -Method Get `
            -Uri "https://api.powerplatform.com/authorization/roleDefinitions?api-version=2022-03-01-preview" `
            -Headers $headersPowerApi 4> $null | `
            Select-Object -ExpandProperty value

        #Saving the latest role definitions to a json file for later use in other cmdlets (like Get-PpacRbacRoleMember and Add-PpacRbacRoleMember)
        $pathMisc = Get-PSFConfigValue -FullName "d365bap.tools.internal.misc.path"
        $resColRaw | ConvertTo-Json -Depth 10 | `
            Set-Content -Path "$pathMisc\Ppac.Rbac.Roles.json" `
            -Force `
            -ErrorAction SilentlyContinue

        $resCol = $resColRaw | Where-Object {
            ($_.roleDefinitionId -like $Role) -or
            ($_.roleDefinitionName -like $Role) -or
            ($_.description -like $Role)
        } | Select-PSFObject -TypeName "D365Bap.Tools.PpacRbacRole" `
            -ExcludeProperty "@odata.etag", "description", "assignableScopes", "restrictedScopes", "permissions" `
            -Property "roleDefinitionId as RoleId",
        "roleDefinitionName as Role",
        "description as Description",
        "assignableScopes as AssignableScopes",
        "restrictedScopes as RestrictedScopes",
        "permissions as Permissions",
        @{Name = "PermissionList"; Expression = { $_.permissions -join "," } },
        @{Name = "RestrictedScopeList"; Expression = { $_.restrictedScopes -join "," } },
        @{Name = "AssignableScopeList"; Expression = { $_.assignableScopes -join "," } },
        *

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacRbacRole"
            return
        }

        $resCol
    }

    end {
        
    }
    
}