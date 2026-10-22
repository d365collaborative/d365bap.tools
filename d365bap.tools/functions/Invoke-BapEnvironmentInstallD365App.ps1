
<#
    .SYNOPSIS
        Invoke the installation of a D365 App in a given environment
        
    .DESCRIPTION
        Enables the invocation of the installation process against the PowerPlatform API (https://api.powerplatform.com)
        
        The cmdlet will keep requesting the status of all invoked installations, until they all have a NON "Running" state
        
        It will request this status every 60 seconds
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
    .PARAMETER PackageId
        The id of the package(s) that you want to have Installed
        
        Accepts:
        * The package Id guid (PpacD365AppId / Id)
        * The package unique name (PpacPackageName / UniqueName), as required by the API install URL
        
        It supports id of current packages, with updates available and new D365 apps
        
        It support an array as input, so it can invoke multiple D365 App installations
        
    .PARAMETER PayloadValue
        Optional payload value sent as '{"payloadValue":"..."}' in the install request body.
        
        Required by some apps with a custom install experience.
        Omit for regular installs / updates.
        
    .PARAMETER PollIntervalSeconds
        Seconds to wait between each status poll against the operations endpoint.
        
        Defaults to 60 seconds.
        
    .PARAMETER TimeoutMinutes
        Maximum time to wait for all installations to reach a terminal state (Succeeded / Failed / Canceled) before giving up polling.
        
        Defaults to 120 minutes. Use 0 to wait indefinitely (not recommended for automation).
        
        When the timeout expires the cmdlet stops polling, warns, and returns the last known statuses so the caller can decide how to proceed.
        
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
        PS C:\> $appIds = @(Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState Installed -UpdatesOnly | Select-Object -ExpandProperty PpacD365AppId)
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
        
    .EXAMPLE
        PS C:\> $apps = @(Get-BapEnvironmentD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -InstallState Installed -UpdatesOnly)
        PS C:\> Invoke-BapEnvironmentInstallD365App -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -PackageId $apps.PpacD365AppId
        
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
        [parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [parameter (Mandatory = $true)]
        [string[]] $PackageId,

        [parameter (Mandatory = $false)]
        [string] $PayloadValue,

        [parameter (Mandatory = $false)]
        [ValidateRange(5, 3600)]
        [int] $PollIntervalSeconds = 60,

        [parameter (Mandatory = $false)]
        [ValidateRange(0, 4320)]
        [int] $TimeoutMinutes = 120
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        # First we will fetch ALL available apps for the environment
        $secureTokenPowerApi = Get-BapAccessToken -ResourceUrl "https://api.powerplatform.com/"
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
        
        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApiValue)"
        }

        $appsAvailable = Get-BapEnvironmentD365App -EnvironmentId $EnvironmentId
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        [System.Collections.Generic.List[System.Object]] $arrInstallStarted = @()
        [System.Collections.Generic.List[System.Object]] $arrStatus = @()
        [System.Collections.Generic.List[System.Object]] $arrFailedStarts = @()

        $headersPowerApi."Content-Type" = "application/json;charset=utf-8"

        if ($PSBoundParameters.ContainsKey('PayloadValue')) {
            $body = @{ payloadValue = $PayloadValue } | ConvertTo-Json -Compress
        }
        else {
            $body = '{}'
        }

        foreach ($pgkId in $PackageId) {
            $appToBeInstalled = $appsAvailable | `
                Where-Object { $_.Id -eq $pgkId -or $_.UniqueName -eq $pgkId -or $_.PpacD365AppId -eq $pgkId -or $_.PpacPackageName -eq $pgkId } | `
                Select-Object -First 1

            if ($null -eq $appToBeInstalled) {
                $messageString = "The combination of the supplied EnvironmentId: <c='em'>$EnvironmentId</c> and PpacD365AppId: <c='em'>$pgkId</c> didn't return any matching D365App. Please verify that the EnvironmentId & PpacD365AppId is correct - try running the <c='em'>Get-BapEnvironmentD365App</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because environment and d365app combination was NOT found based on the supplied parameters." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            }

            $uniqueNameToInstall = $appToBeInstalled.UniqueName
            if ([string]::IsNullOrEmpty($uniqueNameToInstall)) {
                $uniqueNameToInstall = $appToBeInstalled.PpacPackageName
            }

            try {
                $localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/applicationPackages/{1}/install?api-version=2024-10-01" `
                    -f $envObj.PpacEnvId, $uniqueNameToInstall

                $resIntall = Invoke-RestMethod `
                    -Method Post `
                    -Uri $localUri `
                    -Headers $headersPowerApi `
                    -Body $body

                $arrInstallStarted.Add($resIntall)
            }
            catch {
                $startError = $_.Exception.Message
                if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $startError = $_.ErrorDetails.Message }
                $appToBeInstalled | Add-Member -MemberType NoteProperty -Name '_InstallStartError' -Value $startError -Force
                $arrFailedStarts.Add($appToBeInstalled)
            }
        }

        if ($arrFailedStarts.Count -gt 0) {
            $messageString = "The following packages <c='em'>failed to start</c>:"
            Write-PSFMessage -Level Important -Message $messageString

            $arrFailedStarts.ToArray() | Format-Table

            if ($arrFailedStarts.Count -eq $PackageId.Count) {
                Write-PSFMessage -Level Warning -Message "All package installations failed to start. Returning the failure details."
            }
        }

        $pollDeadline = if ($TimeoutMinutes -gt 0) { (Get-Date).AddMinutes($TimeoutMinutes) } else { [datetime]::MaxValue }
        $timedOut = $false
        $pendingCount = 0
        $arrStatus = @()

        if ($arrInstallStarted.Count -gt 0) {
        do {
            Start-Sleep -Seconds $PollIntervalSeconds

            $secureTokenPowerApi = Get-BapAccessToken -ResourceUrl "https://api.powerplatform.com/"
            $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi

            $headersPowerApi = @{
                "Authorization" = "Bearer $($tokenPowerApiValue)"
            }

            $arrStatus = @()

            foreach ($operation in $arrInstallStarted) {
                $localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/operations/{1}?api-version=2024-10-01" `
                    -f $envObj.PpacEnvId, $operation.lastOperation.operationId

                $resInstallOperation = Invoke-RestMethod -Method Get -Uri $localUri -Headers $headersPowerApi
                $arrStatus.Add($resInstallOperation)
            }

            $pendingCount = @($arrStatus | Where-Object { $_.status -in @('NotStarted', 'Running') }).Count

            Write-Progress -Id 1 `
                -Activity "Installing D365 app(s) in '$($envObj.PpacEnvName)'" `
                -Status "$pendingCount of $($arrStatus.Count) operation(s) still active (NotStarted / Running)" `
                -PercentComplete $(if ($arrStatus.Count -gt 0) { (($arrStatus.Count - $pendingCount) / $arrStatus.Count) * 100 } else { 100 })

            $arrStatus | Format-Table

            if ($pendingCount -gt 0 -and (Get-Date) -ge $pollDeadline) {
                $timedOut = $true
                break
            }
        } while ($pendingCount -gt 0)

        Write-Progress -Id 1 -Completed -Activity "Installing D365 app(s) in '$($envObj.PpacEnvName)'"
        }

        if ($timedOut) {
            $messageString = "Polling timed out after <c='em'>$TimeoutMinutes minute(s)</c> with <c='em'>$pendingCount operation(s)</c> still active. Returning the last known statuses."
            Write-PSFMessage -Level Warning -Message $messageString
        }

        foreach ($install in $arrInstallStarted) {
            $opId = $install.lastOperation.operationId
            $final = $arrStatus | Where-Object operationId -eq $opId | Select-Object -First 1

            [PSCustomObject]@{
                PpacD365AppName = $install.localizedName
                PpacPackageName = $install.packageUniqueName
                PackageVersion  = $install.packageVersion
                Status          = $final.status
                StatusMessage   = $final.statusMessage
                ErrorName       = $final.error.errorName
                ErrorMessage    = $final.error.message
                OperationId     = $opId
                TimedOut        = $timedOut
            }
        }

        foreach ($failed in $arrFailedStarts) {
            [PSCustomObject]@{
                PpacD365AppName = $failed.PpacD365AppName
                PpacPackageName = $failed.PpacPackageName
                PackageVersion  = $failed.AvailableVersion
                Status          = 'FailedToStart'
                StatusMessage   = $failed._InstallStartError
                ErrorName       = $null
                ErrorMessage    = $failed._InstallStartError
                OperationId     = $null
                TimedOut        = $false
            }
        }
    }
    
    end {
        
    }
}