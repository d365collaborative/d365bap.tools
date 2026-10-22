
<#
    .SYNOPSIS
        Get D365 Finance and Operations versions for the environment.
        
    .DESCRIPTION
        Enables the user to retrieve the available D365 Finance and Operations application versions for the environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Oldest
        Instructs the cmdlet to return only the oldest available version for the environment.
        
    .PARAMETER Latest
        Instructs the cmdlet to return only the latest available version for the environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365Version -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
        
        This will retrieve all available D365 Finance and Operations versions for the environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365Version -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Oldest
        
        This will retrieve the oldest available D365 Finance and Operations version for the environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365Version -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Latest
        
        This will retrieve the latest available D365 Finance and Operations version for the environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacD365Version {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [Parameter (ParameterSetName = "Lowest")]
        [switch] $Oldest,

        [Parameter (ParameterSetName = "Highest")]
        [switch] $Latest
    )
    
    begin {
        
        $envObj = Get-UnifiedEnvironment `
            -EnvironmentId $EnvironmentId `
            -SkipVersionDetails | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $secureTokenPowerApi = Get-BapAccessToken -ResourceUrl "https://api.powerplatform.com/"
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi

        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApiValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = "https://api.powerplatform.com/dynamics/environments/{0}/finopsversions?api-version=2024-10-01" `
            -f $envObj.PpacEnvId

        $resVersions = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersPowerApi 4> $null | `
            Select-Object -ExpandProperty availableVersions

        $resCol = @(
            $resVersions | Sort-Object -Property { [version]$_.version } | `
                Select-PSFObject -TypeName 'D365Bap.Tools.D365PlatformVersion' `
                -Property `
                @{Name = "EnvironmentId"; Expression = { $envObj.EnvName } }, `
                "version as Version", `
                @{Name = "Platform"; Expression = { $_.version.Substring(0, 7) } }, `
                "releaseStage as ReleaseStage"
        )

        if ($Oldest) {
            $resCol | Select-Object -First 1
        }
        elseif ($Latest) {
            $resCol | Select-Object -Last 1
        }
        else {
            $resCol
        }
    }
    
    end {
        
    }
}