<#
.SYNOPSIS
Get D365 platform update information for the environment.

.DESCRIPTION
Enables the user to retrieve information about the available D365 platform updates for the environment.

.PARAMETER EnvironmentId
The id of the environment that you want to work against.

.PARAMETER Oldest
Instructs the cmdlet to return only the oldest available platform update for the environment.

.PARAMETER Latest
Instructs the cmdlet to return only the latest available platform update for the environment.

.EXAMPLE
PS C:\> Get-PpacD365PlatformUpdate -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"

This will retrieve all available D365 platform updates for the environment.

.EXAMPLE
PS C:\> Get-PpacD365PlatformUpdate -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Oldest

This will retrieve the oldest available D365 platform update for the environment.

.EXAMPLE
PS C:\> Get-PpacD365PlatformUpdate -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Latest

This will retrieve the latest available D365 platform update for the environment.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacD365PlatformUpdate {
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
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization"    = "Bearer $($tokenWebApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal" # minimal || full
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $localUri = $baseUri + '/api/data/v9.2/msprov_getfnoversiondetails'
        
        $resVersions = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersWebApi | `
            Select-Object -ExpandProperty Response | `
            ConvertFrom-Json

        $resCol = @(
            $resVersions | Sort-Object -Property "value" | `
                Select-PSFObject -TypeName 'D365Bap.Tools.D365PlatformVersion' `
                -Property `
            @{Name = "EnvironmentId"; Expression = { $envObj.EnvName } }, `
                "value as Version" `
                , @{Name = "Platform"; Expression = { $_.value.Substring(0, 7) } }

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