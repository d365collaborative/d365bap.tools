<#
    .SYNOPSIS
        Remove a user from a Finance and Operations environment.

    .DESCRIPTION
        Removes the SystemUser record for a Finance and Operations user. Optionally only removes one or more security role assignments and keeps the user.

        Role assignments are removed via DELETE SecurityUserRoles(UserId, SecurityRoleIdentifier), then the user is removed via DELETE SystemUsers(UserID).

    .PARAMETER EnvironmentId
        The ID of the environment to remove the user from.

        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

    .PARAMETER User
        The name or ID of the user to remove from the environment.

        Can be either the user name, user ID or user principal name (UPN).

    .PARAMETER Role
        Only remove the supplied security role assignment(s) and keep the user.

        Can be either the role name or role ID. When omitted the user is fully removed (all roles, then delete).

    .EXAMPLE
        PS C:\> Remove-FscmUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com"

        Removes all security roles from megan.bowen@contoso.com and deletes the FSCM user.

    .EXAMPLE
        PS C:\> Remove-FscmUser -EnvironmentId "ContosoEnv" -User "megan.bowen@contoso.com" -Role "System administrator"

        Only removes the System administrator role assignment and keeps the user.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Remove-FscmUser {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding(SupportsShouldProcess = $true)]
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

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
            "Content-Type"  = "application/json;charset=utf-8"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $matchedUser = Get-FscmUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $User | `
            Select-Object -First 1

        if ($null -eq $matchedUser) {
            Write-PSFMessage -Level Verbose -Message "The user: <c='em'>$User</c> was not found in the Dynamics 365 ERP environment. Nothing to remove."
            return
        }

        $colAssignedRoles = @(Invoke-RestMethod -Method Get `
                -Uri ($baseUri + "/data/SecurityUserRoles?`$filter=UserId eq '$($matchedUser.FscmUserId)'") `
                -Headers $headersFnO 4> $null | `
                Select-Object -ExpandProperty value)

        $colRolesToRemove = @($colAssignedRoles)
        if ($Role.Count -gt 0) {
            $colRolesToRemove = @(
                foreach ($roleName in $Role) {
                    $secRoleObj = Get-FscmSecurityRole `
                        -EnvironmentId $envObj.PpacEnvId `
                        -Name $roleName | `
                        Select-Object -First 1

                    if ($null -eq $secRoleObj) {
                        $messageString = "The supplied Role Name / Id: <c='em'>$roleName</c> didn't return any matching Security Role in the Dynamics 365 ERP environment. Please verify that the Role Name / Id is correct - try running the <c='em'>Get-FscmSecurityRole</c> cmdlet."
                        Write-PSFMessage -Level Important -Message $messageString
                        Stop-PSFFunction -Message "Stopping because Security Role was NOT found based on the Role Name / Id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                        return
                    }

                    $colAssignedRoles | Where-Object { $_.SecurityRoleIdentifier -eq $secRoleObj.FscmRoleId } | Select-Object -First 1
                }
            )
        }

        foreach ($assignedRole in $colRolesToRemove) {
            if ($null -eq $assignedRole) { continue }

            if ($PSCmdlet.ShouldProcess("$($matchedUser.Upn)", "Remove FSCM role $($assignedRole.SecurityRoleIdentifier)")) {
                Invoke-RestMethod -Method Delete `
                    -Uri ($baseUri + "/data/SecurityUserRoles(UserId='$($matchedUser.FscmUserId)',SecurityRoleIdentifier='$($assignedRole.SecurityRoleIdentifier)')") `
                    -Headers $headersFnO `
                    -ContentType $headersFnO.'Content-Type' `
                    -StatusCodeVariable statusUnassign > $null 4> $null

                if (-not ($statusUnassign -like "2*")) {
                    $messageString = "Failed to remove the security role: <c='em'>$($assignedRole.SecurityRoleIdentifier)</c> from the user: <c='em'>$($matchedUser.Upn)</c>. HTTP status: <c='em'>$statusUnassign</c>."
                    Write-PSFMessage -Level Important -Message $messageString
                    Stop-PSFFunction -Message "Stopping because removing the security role failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                    return
                }
            }
        }

        # Role-only mode: keep the user.
        if ($Role.Count -gt 0) { return }

        if ($PSCmdlet.ShouldProcess("$($matchedUser.Upn)", "Remove FSCM user")) {
            Invoke-RestMethod -Method Delete `
                -Uri ($baseUri + "/data/SystemUsers(UserID='$($matchedUser.FscmUserId)')") `
                -Headers $headersFnO `
                -ContentType $headersFnO.'Content-Type' `
                -StatusCodeVariable statusDelete > $null 4> $null

            if (-not ($statusDelete -like "2*")) {
                $messageString = "Failed to delete the user: <c='em'>$($matchedUser.Upn)</c>. HTTP status: <c='em'>$statusDelete</c>."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because deleting the user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }
    }

    end {

    }
}
