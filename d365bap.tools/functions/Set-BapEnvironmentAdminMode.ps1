
<#
    .SYNOPSIS
        Set environment admin mode
        
    .DESCRIPTION
        Enables the user to set the Power Platform environment into Admin Mode or User Mode.
        
        Admin Mode allows only users with the System Administrator role to access the environment, needed for specific maintenance tasks.
        
        User Mode allows all users with appropriate permissions to access the environment.
        
    .PARAMETER EnvironmentId
        Id of the environment that you want to work against.
        
    .PARAMETER Mode
        Specifies the mode to set for the environment.
        
        Valid values are "UserMode" and "AdminMode".
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentAdminMode -EnvironmentId *uat* -Mode AdminMode
        
        This will set the environment with id containing "uat" into Admin Mode.
        
    .EXAMPLE
        PS C:\> Set-BapEnvironmentAdminMode -EnvironmentId *prod* -Mode UserMode
        
        This will set the environment with id containing "prod" into User Mode.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-BapEnvironmentAdminMode {
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
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

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

        $payLoad = [PsCustomObject][ordered]@{
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
            -Body $payLoad `
            -ContentType "application/json" > $null
    }
    
    end {
        
    }
}