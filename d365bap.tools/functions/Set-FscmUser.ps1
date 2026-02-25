
<#
    .SYNOPSIS
        Enables or disables a user in a Finance and Operations environment.
        
    .DESCRIPTION
        This function enables or disables a user in a Finance and Operations environment by calling the appropriate API in the environment.
        
        The user can be specified by their UPN, alias, email, name or UserId in the environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER User
        The user(s) to enable or disable in the Finance and Operations environment.
        
        You can specify one or more users by their UPN, alias, email, name or UserId in the environment.
        
    .PARAMETER State
        Instructs the function to either enable or disable the specified user(s).
        
    .EXAMPLE
        PS C:\> Set-FscmUser -EnvironmentId "env-123" -User "alice@contoso.com" -State Enabled
        
        This will enable the user with the UPN "alice@contoso.com" in the specified environment.
        
    .EXAMPLE
        PS C:\> Set-FscmUser -EnvironmentId "env-123" -User "alice" -State Disabled
        
        This will disable the user with the UserId "alice" in the specified environment.
        
    .EXAMPLE
        PS C:\> Set-FscmUser -EnvironmentId "env-123" -User "alice","bob" -State Enabled
        
        This will enable the users with the UserId "alice" and "bob" in the specified environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-FscmUser {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,
        
        [Parameter (Mandatory = $true)]
        [string[]] $User,

        [Parameter (Mandatory = $true)]
        [ValidateSet("Enabled", "Disabled")]
        [string] $State
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
            "Content-Type"  = "application/json;charset=utf-8"
        }
    
        $colUsers = Get-FscmUser `
            -EnvironmentId $envObj.PpacEnvId
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        foreach ($upn in $User) {
            $matchedUser = $colUsers | Where-Object {
                $_.FscmUserId -eq $upn `
                    -or $_.Upn -eq $upn `
                    -or $_.Alias -eq $upn `
                    -or $_.Email -eq $upn `
                    -or $_.Name -eq $upn
            } | Select-Object -First 1
       
            if ($null -eq $matchedUser) {
                $messageString = "The supplied User: <c='em'>$upn</c> didn't return any matching user details in the Dynamics 365 ERP environment. Please verify that the User is correct - try running the <c='em'>Get-FscmUser</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                continue
            }
        
            $tmpId = $matchedUser.UserId
            
            $enable = $false
            if ($State -eq "Enabled") {
                $enable = $true
            }
            
            $payloadUser = [PsCustomObject][ordered]@{
                "Enabled" = $enable
            } | ConvertTo-Json
                    
            $parmsUser = @{
                Method = "Patch"
                Uri    = $baseUri + "/data/SystemUsers(UserID='$tmpId')"
            }
        
            Invoke-RestMethod @parmsUser `
                -Headers $headersFnO `
                -Body $payloadUser `
                -ContentType $headersFnO.'Content-Type' `
                -StatusCodeVariable statusUser > $null 4> $null

            if (-not $statusUser -like "2*" ) {
                $messageString = "Something went wrong when updating the user: <c='em'>$upn</c> in the Dynamics 365 ERP environment. HTTP Status Code: <c='em'>$statusUser</c>. Please investigate."
                Write-PSFMessage -Level Warning -Message $messageString
                Stop-PSFFunction -Message "Stopping because user could not be updated." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }
    }

    end {
        
    }
}