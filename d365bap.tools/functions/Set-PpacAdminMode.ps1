
<#
    .SYNOPSIS
        Set the admin mode for a Power Platform environment.
        
    .DESCRIPTION
        This cmdlet sets the admin mode for a Power Platform environment. It allows switching between User Mode and Admin Mode, which can be useful for troubleshooting and support scenarios.
        
        Is the same as the administrative mode in LCS.
        
    .PARAMETER EnvironmentId
        The ID of the environment to set the admin mode for.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Mode
        The mode to set for the environment.
        
        Valid values are "UserMode" and "AdminMode".
        
    .EXAMPLE
        PS C:\> Set-PpacAdminMode -EnvironmentId "ContosoEnv" -Mode "AdminMode"
        
        This command sets the admin mode for the Power Platform environment "ContosoEnv" to "AdminMode".
        Now the environment is an admin-only mode.
        
    .EXAMPLE
        PS C:\> Set-PpacAdminMode -EnvironmentId "ContosoEnv" -Mode "UserMode"
        
        This command sets the admin mode for the Power Platform environment "ContosoEnv" to "UserMode".
        Now the environment is in normal user mode and accessible for all users with permissions.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-PpacAdminMode {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [ValidateSet("UserMode", "AdminMode")]
        [string] $Mode
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

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $payload = [PsCustomObject][ordered]@{
            properties = [PsCustomObject][ordered]@{
                states = @{
                    runtime = @{
                        id = if ($Mode -eq "AdminMode") { "AdminMode" } else { "Enabled" }
                    }
                }
            }
        } | ConvertTo-Json -Depth 10

        $localUri = "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($envObj.PpacEnvId)`?api-version=2021-04-01"

        Invoke-RestMethod -Method Patch `
            -Uri $localUri `
            -Headers $headersBapApi `
            -Body $payload `
            -ContentType "application/json" > $null
    }
    
    end {
        
    }
}