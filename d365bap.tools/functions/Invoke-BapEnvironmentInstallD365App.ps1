
<#
    .SYNOPSIS
        Invoke the installation of a D365 App in a given environment
        
    .DESCRIPTION
        This enables the invocation of the installation process against the PowerPlatform API (https://api.powerplatform.com)
        
        The cmdlet will keep requesting the status of all invoked installations, until they all have a NON "Running" state
        
        It will request this status every 60 seconds
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
    .PARAMETER PackageId
        The id of the package(s) that you want to have Installed
        
        It supports id of current packages, with updates available and new D365 apps
        
        It support an array as input, so it can invoke multiple D365 App installations
        
    .EXAMPLE
        PS C:\> Invoke-BapEnvironmentInstallD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -PackageId 'be69fc64-7393-4c3c-8908-2a1c2e53aef9','6defa8de-87f9-4478-8f9a-a7d685394e24'
        
        This will install the 2 x D365 Apps, based on the Ids supplied.
        It will run the cmdlet and have it get the status of the installation progress until all D365 Apps have been fully installed.
        
        Sample output (Install initialized):
        status  createdDateTime     lastActionDateTime  error statusMessage operationId
        ------  ---------------     ------------------  ----- ------------- -----------
        Running 02/03/2024 13.42.07 02/03/2024 13.42.16                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
        Running 02/03/2024 13.42.09 02/03/2024 13.42.12                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d
        
        Sample output (Partly succeeded installation):
        status    createdDateTime     lastActionDateTime  error statusMessage operationId
        ------    ---------------     ------------------  ----- ------------- -----------
        Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
        Running   02/03/2024 13.42.09 02/03/2024 13.45.55                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d
        
        Sample output (Completely succeeded installation):
        status    createdDateTime     lastActionDateTime  error statusMessage operationId
        ------    ---------------     ------------------  ----- ------------- -----------
        Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
        Succeeded 02/03/2024 13.42.09 02/03/2024 13.48.26                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d
        
    .EXAMPLE
        PS C:\> $appIds = @(Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState Installed -UpdatesOnly | Select-Object -ExpandProperty PackageId)
        PS C:\> Invoke-BapEnvironmentInstallD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -PackageId $appIds
        
        This will find all D365 Apps that has a pending update available.
        It will gather the Ids into an array.
        It will run the cmdlet and have it get the status of the installation progress until all D365 Apps have been fully installed.
        
        Sample output (Install initialized):
        status  createdDateTime     lastActionDateTime  error statusMessage operationId
        ------  ---------------     ------------------  ----- ------------- -----------
        Running 02/03/2024 13.42.07 02/03/2024 13.42.16                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
        Running 02/03/2024 13.42.09 02/03/2024 13.42.12                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d
        
        Sample output (Partly succeeded installation):
        status    createdDateTime     lastActionDateTime  error statusMessage operationId
        ------    ---------------     ------------------  ----- ------------- -----------
        Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
        Running   02/03/2024 13.42.09 02/03/2024 13.45.55                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d
        
        Sample output (Completely succeeded installation):
        status    createdDateTime     lastActionDateTime  error statusMessage operationId
        ------    ---------------     ------------------  ----- ------------- -----------
        Succeeded 02/03/2024 13.42.07 02/03/2024 13.44.48                     5c80df7f-d89e-42bd-abeb-98e577ae49f4
        Succeeded 02/03/2024 13.42.09 02/03/2024 13.48.26                     6885e0f4-639f-4ebc-b21e-49ce5d5e920d
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-BapEnvironmentInstallD365App {
    [CmdletBinding()]
    param (
        [parameter (mandatory = $true)]
        [string] $EnvironmentId,

        [parameter (mandatory = $true)]
        [string[]] $PackageId
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        # First we will fetch ALL available apps for the environment
        $tokenPowerApi = Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/"
        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApi.Token)"
        }
        
        $appsAvailable = Get-BapEnvironmentD365App -EnvironmentId $EnvironmentId
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        [System.Collections.Generic.List[System.Object]] $arrInstallStarted = @()
        [System.Collections.Generic.List[System.Object]] $arrStatus = @()

        $headersPowerApi."Content-Type" = "application/json;charset=utf-8"

        foreach ($pgkId in $PackageId) {
            $appToBeInstalled = $appsAvailable | Where-Object Id -eq $pgkId | Select-Object -First 1

            if ($null -eq $appToBeInstalled) {
                $messageString = "The combination of the supplied EnvironmentId: <c='em'>$EnvironmentId</c> and PackageId: <c='em'>$PackageId</c> didn't return any matching D365App. Please verify that the EnvironmentId & PackageId is correct - try running the <c='em'>Get-BapEnvironmentD365App</c> cmdlet."
                Write-PSFMessage -Level Host -Message $messageString
                Stop-PSFFunction -Message "Stopping because environment and d365app combination was NOT found based on the supplied parameters." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            }

            $body = $appToBeInstalled | ConvertTo-Json
            $resIntall = Invoke-RestMethod -Method Post -Uri "https://api.powerplatform.com/appmanagement/environments/$EnvironmentId/applicationPackages/$($appToBeInstalled.uniqueName)/install?api-version=2022-03-01-preview" -Headers $headersPowerApi -Body $body

            $arrInstallStarted.Add($resIntall)
        }

        do {
            $tokenPowerApi = Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/"
            $headersPowerApi = @{
                "Authorization" = "Bearer $($tokenPowerApi.Token)"
            }

            Start-Sleep -Seconds 60
            # Write-PSFMessage -Level Host -Message "Checking for running operations"

            $arrStatus = @()

            foreach ($operation in $arrInstallStarted) {
                $resInstallOperation = Invoke-RestMethod -Method Get -Uri "https://api.powerplatform.com/appmanagement/environments/$EnvironmentId/operations/$($operation.lastOperation.operationId)?api-version=2022-03-01-preview" -Headers $headersPowerApi
                $arrStatus.Add($resInstallOperation)
            }

            $arrStatus | Format-Table
        } while ("Running" -in $arrStatus.status)
    }
    
    end {
        
    }
}