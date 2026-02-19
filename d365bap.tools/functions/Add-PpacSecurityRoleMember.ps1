
<#
    .SYNOPSIS
        Enables assignment of a user to a security role in the Power Platform environment.
        
    .DESCRIPTION
        This cmdlet assigns a user to one or more security roles in the specified Power Platform environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER User
        The user that you want to assign to the security role.
        
        Can be either the User Principal Name (UPN) or the UserId of the user in the Power Platform environment.
        
    .PARAMETER Role
        The security role that you want to assign to the user.
        
        Can be either the role name or the role ID.
        
    .EXAMPLE
        PS C:\> Add-PpacSecurityRoleMember -EnvironmentId "env-123" -User "alice" -Role "System Customizer"
        
        This will assign the user "alice" to the "System Customizer" security role in the environment with the id "env-123".
        
    .EXAMPLE
        PS C:\> Add-PpacSecurityRoleMember -EnvironmentId "env-123" -User "alice@contoso.com" -Role "System Customizer", "Environment Maker"
        
        This will assign the user "alice@contoso.com" to the "System Customizer" and "Environment Maker" security roles in the environment with the id "env-123".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Add-PpacSecurityRoleMember {
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

        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }

        $colSecurityRoles = Get-PpacSecurityRole `
            -EnvironmentId $envObj.PpacEnvId

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $crmUser = Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $User | `
            Select-Object -First 1

        if (Test-PSFFunctionInterrupt) { return }

        if ($null -eq $crmUser) {
            $messageString = "The supplied User: <c='em'>$User</c> is not an user in the Power Platform environment. Please verify that the user exists in the environment - try running the <c='em'>Get-PpacUser</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because user was NOT found based on the UPN." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        foreach ($roleName in $role) {
            $roleObj = $colSecurityRoles | `
                Where-Object Name -eq $roleName | `
                Select-Object -First 1

            if ($null -eq $roleObj) {
                $messageString = "The supplied RoleName: <c='em'>$roleName</c> is not a valid Security Role in the Power Platform environment. Please verify that the role exists in the environment - try running the <c='em'>Get-PpacSecurityRole</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                continue
            }

            # Now we need to assign the Security Role to the application user in the Power Platform environment using the Web API
            $payload = [PsCustomObject][ordered]@{
                "@odata.id" = $baseUri + "/api/data/v9.2/roles($($roleObj.PpacRoleId))"
            } | ConvertTo-Json -Depth 10

            $localUri = $baseUri + "/api/data/v9.2/systemusers($($crmUser.PpacSystemUserId))/systemuserroles_association/`$ref"
           
            Invoke-RestMethod -Method Post `
                -Uri $localUri `
                -Headers $headersWebApi `
                -ContentType "application/json" `
                -Body $payload `
                -StatusCodeVariable statusRole > $null 4> $null

            if (-not ($statusRole -like "2*")) {
                $messageString = "Failed to assign the Security Role: <c='em'>$($roleObj[0].Name)</c> to the user in the Power Platform environment. Please try assigning the role manually via the Power Platform admin center - <c='em'>https://aka.ms/ppac</c>"
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because assigning the Security Role to the user failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }

        Get-PpacUser `
            -EnvironmentId $envObj.PpacEnvId `
            -User $User
    }
    
    end {
        
    }
}