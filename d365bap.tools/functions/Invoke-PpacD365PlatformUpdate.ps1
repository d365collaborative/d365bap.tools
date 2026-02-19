
<#
    .SYNOPSIS
        Start D365 Platform update.
        
    .DESCRIPTION
        Invokes the D365 Platform update process for a given environment and version.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER Version
        The version of the D365 Platform to update/install.
        
    .EXAMPLE
        PS C:\> Invoke-PpacD365PlatformUpdate -EnvironmentId "env-123" -Version "10.0.45.4"
        
        This will queue the update/install of D365 Platform version 10.0.45.4 for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365PlatformUpdate -EnvironmentId "env-123" -Latest | Invoke-PpacD365PlatformUpdate
        
        This will get the latest available D365 Platform version for the specified environment.
        It will then queue the update/install of that version for the specified environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365PlatformUpdate -EnvironmentId "env-123" -Oldest | Invoke-PpacD365PlatformUpdate
        
        This will get the oldest available D365 Platform version for the specified environment.
        It will then queue the update/install of that version for the specified environment.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-PpacD365PlatformUpdate {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $EnvironmentId,

        [parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [version] $Version
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
            return
        }
        
        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
            "Content-Type"  = "application/json"
        }
        
        <#
            Platform version is 10.0.X for humans, but the application package version is 10.0.X.Y,
            so we need to get the latest available version and find the matching one.
        #>
        $tmpVersion = $Version.ToString().Substring(0, 7)
        $colVersions = Get-PpacD365PlatformUpdate -EnvironmentId $EnvironmentId
        $deployVersion = $colVersions | Where-Object Platform -eq $tmpVersion

        if ($null -eq $deployVersion) {
            $messageString = "The specified version <c='em'>$Version</c> was not valid for the environment. Please verify the available versions using the <c='em'>Get-PpacD365PlatformUpdate</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "The specified version was not valid for the environment." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $localUri = $baseUri + '/api/data/v9.2/msprov_queuefnoinstallorupdate'
        
        $payload = [PsCustomObject][ordered]@{
            "payload" = "ApplicationVersion=$deployVersion"
        } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersWebApi `
            -Body $payload `
            -ContentType "application/json" `
            -SkipHttpErrorCheck `
            -StatusCodeVariable 'statusProvision' > $null 4>$null

        if (-not ($statusProvision -like "2**")) {
            $messageString = "Failed to queue D365 Platform update to version: <c='em'>$Version</c> for environment: <c='em'>$($envObj.EnvironmentName)</c>. Please investigate the issue - HTTP status code: $statusProvision."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because queuing the D365 Platform update failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        Write-PSFMessage -Level Verbose -Message "Waiting for the D365 Platform update to start processing..."
        Start-Sleep -Seconds 30

        $appObj = Get-PpacD365App `
            -EnvironmentId $EnvironmentId `
            -Name 'Dynamics 365 Finance and Operations Provisioning App'

        # Output the app details, for the user to see
        $appObj
    }
    
    end {
        
    }
}