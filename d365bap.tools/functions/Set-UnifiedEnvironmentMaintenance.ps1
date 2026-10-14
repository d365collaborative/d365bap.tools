
<#
    .SYNOPSIS
        Set maintenance settings for a Unified Environment in Power Platform Admin Center (PPAC).
        
    .DESCRIPTION
        Updates the Finance and Operations maintenance settings for a Unified Environment.
        
        Wraps the Power Platform API endpoint:
        PUT https://api.powerplatform.com/dynamics/environments/{environmentId}/finopsadminsettings?api-version=2024-10-01
        
        Supports updating the maintenance window cadence for major version application updates
        and the preferred days of week for updates.
        
        Support D365 Finance and Operations Unified Environments, either Developer Edition (UDE) or Unified Sandbox Environment (USE).
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Cadence
        Cadence for major version application updates.
        
        Valid values are:
        - "EveryUpdate": Apply every major version application update.
        - "EveryOtherUpdate": Apply every other major version application update.
        - "Regulated": Regulated cadence for major version application updates.
        
    .PARAMETER DaysOfWeek
        The preferred days of week for updates.
        
        Valid values are Sunday, Monday, Tuesday, Wednesday, Thursday, Friday and Saturday.
        
    .EXAMPLE
        PS C:\> Set-UnifiedEnvironmentMaintenance -EnvironmentId "es-ude-motz-01" -Cadence EveryOtherUpdate
        
        This will set the maintenance window cadence to 'EveryOtherUpdate' for the environment "es-ude-motz-01".
        
    .EXAMPLE
        PS C:\> Set-UnifiedEnvironmentMaintenance -EnvironmentId "es-ude-motz-01" -DaysOfWeek Saturday, Sunday
        
        This will set the preferred maintenance days to Saturday and Sunday for the environment "es-ude-motz-01".
        
    .EXAMPLE
        PS C:\> Set-UnifiedEnvironmentMaintenance -EnvironmentId "es-ude-motz-01" -Cadence EveryUpdate -DaysOfWeek Saturday
        
        This will set the maintenance window cadence to 'EveryUpdate' and the preferred maintenance day to Saturday.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Set-UnifiedEnvironmentMaintenance {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [ValidateSet("EveryUpdate", "EveryOtherUpdate", "Regulated")]
        [string] $Cadence,

        [ValidateSet("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")]
        [string[]] $DaysOfWeek
    )
    
    begin {
        if ([System.String]::IsNullOrWhiteSpace($Cadence) -and ($null -eq $DaysOfWeek -or $DaysOfWeek.Count -eq 0)) {
            $messageString = "You must supply either <c='em'>-Cadence</c> or <c='em'>-DaysOfWeek</c> (or both) to update the maintenance settings."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because neither Cadence nor DaysOfWeek was supplied." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if (Test-PSFFunctionInterrupt) { return }

        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi

        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApiValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $bodyObj = [PsCustomObject][ordered]@{}

        if (-not [System.String]::IsNullOrWhiteSpace($Cadence)) {
            $bodyObj | Add-Member -MemberType NoteProperty -Name "updatedMaintenanceWindowCadence" -Value $Cadence
        }

        if ($null -ne $DaysOfWeek -and $DaysOfWeek.Count -gt 0) {
            $bodyObj | Add-Member -MemberType NoteProperty -Name "updatedMaintenanceWindowDaysOfWeek" -Value $DaysOfWeek
        }

        $payload = $bodyObj | ConvertTo-Json -Depth 10

        $localUri = "https://api.powerplatform.com/dynamics/environments/$($envObj.PpacEnvId)/finopsadminsettings?api-version=2024-10-01"

        $maintenanceParams = @{
            Method             = 'Put'
            Uri                = $localUri
            Headers            = $headersPowerApi
            Body               = $payload
            ContentType        = 'application/json'
            SkipHttpErrorCheck = $true
            StatusCodeVariable = 'statusMaintenance'
        }

        $resObj = Invoke-RestMethod @maintenanceParams 4> $null

        if (-not ($statusMaintenance -like "2**")) {
            $messageString = "Failed to update the maintenance settings for environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)). HTTP status code: $statusMaintenance."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because updating the maintenance settings failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $resObj | Select-PSFObject -TypeName "D365Bap.Tools.UnifiedEnvironmentMaintenance" `
            -Property "maintenanceWindowCadence as Cadence",
        "maintenanceWindowDaysOfWeek as DaysOfWeek",
        @{Name = "PpacEnvId"; Expression = { $envObj.PpacEnvId } },
        @{Name = "PpacEnvName"; Expression = { $envObj.PpacEnvName } },
        *
    }
    
    end {
        
    }
}
