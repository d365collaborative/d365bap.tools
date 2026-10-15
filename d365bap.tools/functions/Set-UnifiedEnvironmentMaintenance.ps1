
<#
    .SYNOPSIS
        Set maintenance settings for a Unified Environment in Power Platform Admin Center (PPAC).
        
    .DESCRIPTION
        Updates the Finance and Operations maintenance settings for a Unified Environment.
        
        Supports updating the maintenance window cadence for major version application updates and the preferred days of week for updates.
        
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
        PS C:\> Set-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Cadence EveryOtherUpdate
        
        This will set the maintenance window cadence to 'EveryOtherUpdate' for the environment "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".
        
    .EXAMPLE
        PS C:\> Set-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -DaysOfWeek Saturday, Sunday
        
        This will set the preferred maintenance days to Saturday and Sunday for the environment "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".
        
    .EXAMPLE
        PS C:\> Set-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Cadence EveryUpdate -DaysOfWeek Saturday
        
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

        $envObj = Get-UnifiedEnvironment -EnvironmentId $EnvironmentId `
            -SkipVersionDetails | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."
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

        $localUri = "https://api.powerplatform.com/dynamics/environments/{0}/finopsadminsettings?api-version=2024-10-01" `
            -f $envObj.PpacEnvId

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
