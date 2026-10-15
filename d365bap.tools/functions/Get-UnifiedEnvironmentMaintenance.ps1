
<#
    .SYNOPSIS
        Get maintenance settings for a Unified Environment in Power Platform Admin Center (PPAC).
        
    .DESCRIPTION
        Retrieves the Finance and Operations maintenance settings for a Unified Environment.
        
        Returns the maintenance window cadence and the preferred days of week for updates.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentMaintenance -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
        
        This will retrieve the maintenance settings for the environment "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UnifiedEnvironmentMaintenance {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId
    )
    
    begin {
        $envObj = Get-UnifiedEnvironment `
            -EnvironmentId $EnvironmentId `
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

        $localUri = "https://api.powerplatform.com/dynamics/environments/{0}/finopsadminsettings?api-version=2024-10-01" `
            -f $envObj.PpacEnvId

        $maintenanceParams = @{
            Method             = 'Get'
            Uri                = $localUri
            Headers            = $headersPowerApi
            SkipHttpErrorCheck = $true
            StatusCodeVariable = 'statusMaintenance'
        }

        $resObj = Invoke-RestMethod @maintenanceParams 4> $null

        if (-not ($statusMaintenance -like "2**")) {
            $messageString = "Failed to retrieve the maintenance settings for environment: <c='em'>$($envObj.PpacEnvName)</c> ($($envObj.PpacEnvId)). HTTP status code: $statusMaintenance."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because retrieving the maintenance settings failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
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
