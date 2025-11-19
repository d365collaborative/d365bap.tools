
<#
    .SYNOPSIS
        Get FnO/FinOps Application update versions.
        
    .DESCRIPTION
        Retrieves available FnO/FinOps Application update versions for a given environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Oldest
        Instructs the function to return only the oldest available version.
        
    .PARAMETER Latest
        Instructs the function to return only the latest available version.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123"
        
        This will retrieve all available FnO/FinOps Application update versions for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123" -Latest
        
        This will retrieve the latest available FnO/FinOps Application update version for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123" -Oldest
        
        This will retrieve the oldest available FnO/FinOps Application update version for the specified environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentFnOAppUpdate {
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
            "Authorization" = "Bearer $($tokenWebApiValue)"
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
                Select-PSFObject -TypeName 'D365Bap.Tools.FnOAppVersion' `
                -Property `
            @{Name = "EnvironmentId"; Expression = { $envObj.EnvName } }, `
                "value as Version"
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