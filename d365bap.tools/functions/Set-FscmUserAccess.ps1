
<#
    .SYNOPSIS
        Enable or disable user access in a Dynamics 365 Finance & Operations environment
        
    .DESCRIPTION
        Updates the Enabled flag on one or more users in the SystemUsers OData endpoint of a Dynamics 365 Finance & Operations (FSCM) environment.
        
        Users can be identified by their FscmUserId, UPN, alias, email address, or display name.
        Use -Enabled to grant access; omit it (or use -Enabled:$false) to revoke access.
        
    .PARAMETER EnvironmentId
        The id of the environment you want to update users in.
        
        This can be obtained from the Get-BapEnvironment cmdlet.
        
    .PARAMETER User
        The user(s) to update.
        
        Accepts one or more identifiers per user. Each value is matched against: FscmUserId, UPN, alias, email address, and display name — in that order.
        
    .PARAMETER Enabled
        Switch to enable the user account(s).
        
        Omit this switch (default) to disable the user account(s).
        
    .EXAMPLE
        PS C:\> Set-FscmUserAccess -EnvironmentId "eec2c631-a3ec-4b02-8ebc-b67f89e77ba0" -User "john.doe@contoso.com" -Enabled
        
        Enables user john.doe@contoso.com in the specified environment.
        
    .EXAMPLE
        PS C:\> Set-FscmUserAccess -EnvironmentId "eec2c631-a3ec-4b02-8ebc-b67f89e77ba0" -User "john.doe@contoso.com"
        
        Disables user john.doe@contoso.com in the specified environment.
        
    .EXAMPLE
        PS C:\> Set-FscmUserAccess -EnvironmentId "eec2c631-a3ec-4b02-8ebc-b67f89e77ba0" -User "john.doe@contoso.com","jane.doe@contoso.com" -Enabled
        
        Enables both john.doe and jane.doe in the specified environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-FscmUserAccess {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,
        
        [Parameter (Mandatory = $true)]
        [string[]] $User,

        [switch] $Enabled
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
            
            $payloadUser = [PsCustomObject][ordered]@{
                "Enabled" = [bool]$Enabled
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