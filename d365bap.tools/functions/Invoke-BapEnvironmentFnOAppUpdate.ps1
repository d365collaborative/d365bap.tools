
<#
    .SYNOPSIS
        Start FnO/FinOps Application update/install.
        
    .DESCRIPTION
        Invokes the FnO/FinOps Application update/install process for a given environment and version.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Version
        The version of the FnO/FinOps Application to update/install.
        
    .EXAMPLE
        PS C:\> Invoke-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123" -Version "10.0.45.4"
        
        This will queue the update/install of FnO/FinOps Application version 10.0.45.4 for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123" -Latest | Invoke-BapEnvironmentFnOAppUpdate
        
        This will get the latest available FnO/FinOps Application version for the specified environment.
        It will then queue the update/install of that version for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentFnOAppUpdate -EnvironmentId "env-123" -Oldest | Invoke-BapEnvironmentFnOAppUpdate
        
        This will get the oldest available FnO/FinOps Application version for the specified environment.
        It will then queue the update/install of that version for the specified environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-BapEnvironmentFnOAppUpdate {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $EnvironmentId,

        [parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $Version
    )
    
    begin {
        
    }
    
    process {
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
            "Content-Type"  = "application/json"
        }

        if (Test-PSFFunctionInterrupt) { return }
        
        $localUri = $baseUri + '/api/data/v9.2/msprov_queuefnoinstallorupdate'
        
        $payload = [PsCustomObject][ordered]@{
            "payload" = "ApplicationVersion=$Version"
        } | ConvertTo-Json -Depth 3

        $resRequest = Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersWebApi `
            -Body $payload `
            -ContentType "application/json" `
            -SkipHttpErrorCheck | `
            Select-Object -ExpandProperty queuefnoinstallorupdateresponse

        if ($null -eq $resRequest) {
            $messageString = "Failed to queue the update/install of FinOps Application version <c='em'>$Version</c> for environment <c='em'>$($envObj.PpacEnvName)</c>. Please verify that the version exists using <c='em'>Get-BapEnvironmentFnOAppUpdate</c> and try again."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because the update/install could not be queued." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $resRequest | ConvertFrom-Json
    }
    
    end {
        
    }
}