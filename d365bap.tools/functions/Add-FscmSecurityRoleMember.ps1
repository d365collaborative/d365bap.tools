
<#
    .SYNOPSIS
        Enables assignment of a user to a security role in the Dynamics 365 ERP environment.
        
    .DESCRIPTION
        This cmdlet assigns a user to one or more security roles in the specified Dynamics 365 ERP environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER User
        The user that you want to assign to the security role.
        
        Can be either the User Principal Name (UPN) or the UserId of the user in the Dynamics 365 ERP environment.
        
    .PARAMETER Role
        The security role that you want to assign to the user.
        
        Can be either the role name or the role ID.
        
    .EXAMPLE
        PS C:\> Add-FscmSecurityRoleMember -EnvironmentId "env-123" -User "alice" -Role "Sales Clerk"
        
        This will assign the user "alice" to the "Sales Clerk" security role in the environment with the id "env-123".
        
    .EXAMPLE
        PS C:\> Add-FscmSecurityRoleMember -EnvironmentId "env-123" -User "alice@contoso.com" -Role "Sales Clerk", "Sales Manager"
        
        This will assign the user "alice@contoso.com" to the "Sales Clerk" and "Sales Manager" security roles in the environment with the id "env-123".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-FscmSecurityRoleMember {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (Mandatory = $true)]
        [string] $User,

        [Parameter (Mandatory = $true)]
        [Alias('RoleName')]
        [string[]] $Role
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
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
        }

        $colSecurityRoles = Get-FscmSecurityRole `
            -EnvironmentId $envObj.PpacEnvId

        if (Test-PSFFunctionInterrupt) { return }
    
        $userObj = Get-FscmUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $User | `
            Select-Object -First 1

        if (Test-PSFFunctionInterrupt) { return }

        if ($null -eq $userObj) {
            $messageString = "The supplied User: <c='em'>$User</c> is not an user in the Dynamics 365 ERP environment. Please verify that the user exists in the environment - try running the <c='em'>Get-FscmUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found based on the UPN." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($roleName in $role) {
            $roleObj = $colSecurityRoles | `
                Where-Object Name -eq $roleName | `
                Select-Object -First 1

            if ($null -eq $roleObj) {
                $messageString = "The supplied RoleName: <c='em'>$roleName</c> is not a valid Security Role in the Dynamics 365 ERP environment. Please verify that the role exists in the environment - try running the <c='em'>Get-FscmSecurityRole</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                continue
            }

            $payload = [PsCustomObject][ordered]@{
                "SecurityRoleIdentifier" = $roleObj.FscmRoleId
                "UserId"                 = $userObj.FscmUserId
                "AssignmentStatus"       = "Enabled"
                "AssignmentMode"         = "Manual"
                "SecurityRoleName"       = $roleObj.Name
                "UserLicenseType"        = $roleObj.License
            } | ConvertTo-Json

            Invoke-RestMethod -Method Post `
                -Uri ($baseUri + '/data/SecurityUserRoles') `
                -Headers $headersFnO `
                -Body $payload `
                -ContentType $headersFnO.'Content-Type' `
                -StatusCodeVariable statusUserRoleMapping > $null 4> $null

            if (-not $statusUserRoleMapping -like "2*" ) {
                $messageString = "Something went wrong when assigning the user: <c='em'>$($userObj.FscmUserId) - $($userObj.Upn)</c> to the role: <c='em'>$($roleObj.Name)</c> in the Dynamics 365 ERP environment. HTTP Status Code: <c='em'>$statusUserRoleMapping</c>. Please investigate."
                Write-PSFMessage -Level Warning -Message $messageString
                continue
            }

        }
    }
    
    end {
        
    }
}