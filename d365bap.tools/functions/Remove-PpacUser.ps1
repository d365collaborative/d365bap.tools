<#
    .SYNOPSIS
        Remove a user from a Power Platform environment.

    .DESCRIPTION
        Removes the Dataverse systemuser for a Microsoft Entra ID user. Optionally only removes one or more security role assignments and keeps the user.

        Removal order is enforced by the platform:
        all role assignments must be removed first, then the user must be disabled before DELETE.
        Users that still exist in Entra ID cannot be hard deleted (0x80048359) - those stay in place as disabled users without roles.

    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.

        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

    .PARAMETER User
        The user that you want to remove from the Power Platform environment.

        Can be either the User Principal Name (UPN), mail address or Entra object id.

    .PARAMETER Role
        Only remove the supplied security role assignment(s) and keep the user.

        Can be either the role name or the role ID. When omitted the user is fully removed (all roles, disable, delete).

    .EXAMPLE
        PS C:\> Remove-PpacUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com"

        Removes all security roles from megan.bowen@contoso.com, disables the user and deletes it. When the user still exists in Entra ID it stays as a disabled user without roles.

    .EXAMPLE
        PS C:\> Remove-PpacUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com" -Role "System Administrator"

        Only removes the System Administrator role assignment and keeps the user.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Remove-PpacUser {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $User,

        [Alias('RoleName')]
        [string[]] $Role
    )

    begin {
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }

        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
            "Content-Type"  = "application/json"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $crmUser = Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $User | `
            Select-Object -First 1

        if ($null -eq $crmUser) {
            Write-PSFMessage -Level Verbose -Message "The user: <c='em'>$User</c> was not found in the Power Platform environment. Nothing to remove."
            return
        }

        $colAssignedRoles = @(Invoke-RestMethod -Method Get `
                -Uri ($baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))/systemuserroles_association?`$select=name,roleid") `
                -Headers $headersWebApi 4> $null | `
                Select-Object -ExpandProperty value)

        $colRolesToRemove = @($colAssignedRoles)
        if ($Role.Count -gt 0) {
            $colRoles = Get-PpacSecurityRole `
                -EnvironmentId $envObj.PpacEnvId `
                -IncludeAll

            $colRolesToRemove = @(
                foreach ($roleName in $Role) {
                    $roleObj = $colRoles | Where-Object { $_.Name -eq $roleName -or $_.PpacRoleId -eq $roleName } | Select-Object -First 1

                    if ($null -eq $roleObj) {
                        $messageString = "The supplied Role: <c='em'>$roleName</c> didn't return any matching security role details in the Power Platform environment. Please verify that the Role name is correct - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
                        Write-PSFMessage -Level Important -Message $messageString
                        Stop-PSFFunction -Message "Stopping because no matching security role was found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                        return
                    }

                    $colAssignedRoles | Where-Object { $_.roleid -eq $roleObj.PpacRoleId } | Select-Object -First 1
                }
            )
        }

        foreach ($assignedRole in $colRolesToRemove) {
            if ($null -eq $assignedRole) { continue }

            $roleRef = $baseUri + "/api/data/v9.2/roles($($assignedRole.roleid))"
            $unassignUri = $baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))/systemuserroles_association/`$ref?`$id=$([uri]::EscapeDataString($roleRef))"

            Invoke-RestMethod -Method Delete `
                -Uri $unassignUri `
                -Headers $headersWebApi `
                -StatusCodeVariable statusUnassign > $null 4> $null

            if (-not ($statusUnassign -like "2*")) {
                $messageString = "Failed to remove the security role: <c='em'>$($assignedRole.name)</c> from the user: <c='em'>$($crmUser.Upn)</c>. HTTP status: <c='em'>$statusUnassign</c>."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because removing the security role failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }

        # Role-only mode: keep the user.
        if ($Role.Count -gt 0) { return }

        $payloadDisable = [PsCustomObject][ordered]@{
            "isdisabled" = $true
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Method Patch `
            -Uri ($baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))") `
            -Headers $headersWebApi `
            -Body $payloadDisable `
            -StatusCodeVariable statusDisable > $null 4> $null

        if (-not ($statusDisable -like "2*")) {
            $messageString = "Failed to disable the user: <c='em'>$($crmUser.Upn)</c>. The user must be disabled before deletion. HTTP status: <c='em'>$statusDisable</c>."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because disabling the user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        try {
            Invoke-RestMethod -Method Delete `
                -Uri ($baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))") `
                -Headers $headersWebApi `
                -StatusCodeVariable statusDelete > $null 4> $null

            if (-not ($statusDelete -like "2*")) {
                throw [System.Exception]::new("HTTP status: $statusDelete")
            }
        }
        catch {
            # Users that still exist in Entra ID cannot be hard deleted (0x80048359).
            # They stay in place as disabled users without roles, which is the closest removable state.
            if ("$($_.ErrorDetails.Message)" -like "*0x80048359*") {
                Write-PSFMessage -Level Important -Message "The user: <c='em'>$($crmUser.Upn)</c> still exists in Entra ID and cannot be hard deleted. It is left as a disabled user without security roles."
                return
            }

            $messageString = "Failed to delete the user: <c='em'>$($crmUser.Upn)</c>. $($_.Exception.Message)"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because deleting the user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -ErrorRecord $_
            return
        }
    }

    end {

    }
}
