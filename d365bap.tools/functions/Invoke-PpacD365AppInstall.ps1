
<#
    .SYNOPSIS
        Installs D365 applications in the environment.
        
    .DESCRIPTION
        Enables the user to install D365 applications in the environment as it would be done in Power Platform Admin Center (PPAC).
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER D365App
        The name, unique name or package name of the D365 application you want to install in the environment.
        
        Supports single or multiple application names.
        
    .EXAMPLE
        PS C:\> Invoke-PpacD365AppInstall -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -D365App "Invoice Capture for Dynamics 365 Finance"
        
        This will install the "Invoice Capture for Dynamics 365 Finance" application in the environment.
        
    .EXAMPLE
        PS C:\> Invoke-PpacD365AppInstall -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -D365App "msdyn_FnoInvoiceCaptureAnchor"
        
        This will install the "Invoice Capture for Dynamics 365 Finance" application in the environment.
        It will use the unique name of the application (msdyn_FnoInvoiceCaptureAnchor) to find the application and install it.
        
    .EXAMPLE
        PS C:\> Invoke-PpacD365AppInstall -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -D365App "MicrosoftOperationsVEAnchor","msdyn_FnoInvoiceCaptureAnchor"
        
        This will install the "Microsoft Operations VE" and "Invoice Capture for Dynamics 365 Finance" applications in the environment.
        It will use the unique name of the D365 applications to find the applications and install them.
        It will start the installation of both applications, and then wait for the installation process to finish.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-PpacD365AppInstall {
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [parameter (Mandatory = $true)]
        [string[]] $D365App
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment `
            -EnvironmentId $EnvironmentId | `
            Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        # First we will fetch ALL available apps for the environment
        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
        
        $headersPowerApi = @{
            "Authorization" = "Bearer $($tokenPowerApiValue)"
        }

        $appsAvailable = Get-PpacD365App `
            -EnvironmentId $EnvironmentId
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        [System.Collections.Generic.List[System.Object]] $arrInstallStarted = @()
        [System.Collections.Generic.List[System.Object]] $arrStatus = @()
        [System.Collections.Generic.List[System.Object]] $arrFailedStarts = @()

        $headersPowerApi."Content-Type" = "application/json;charset=utf-8"

        foreach ($appName in $D365App) {
            $appToBeInstalled = $appsAvailable | `
                Where-Object { $_.PpacD365AppId -eq $appName -or
                $_.PpacD365AppName -eq $appName -or
                $_.PpacPackageName -eq $appName } | `
                Select-Object -First 1

            if ($null -eq $appToBeInstalled) {
                $messageString = "The combination of the supplied EnvironmentId: <c='em'>$EnvironmentId</c> and PpacD365AppId: <c='em'>$appName</c> didn't return any matching D365App. Please verify that the EnvironmentId & PpacD365AppId is correct - try running the <c='em'>Get-BapEnvironmentD365App</c> cmdlet."
                Write-PSFMessage -Level Important -Message $messageString
                Stop-PSFFunction -Message "Stopping because environment and d365app combination was NOT found based on the supplied parameters." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            }

            try {
                $localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/applicationPackages/{1}/install?api-version=2022-03-01-preview" `
                    -f $envObj.PpacEnvId `
                    , $appToBeInstalled.PpacPackageName

                $resIntall = Invoke-RestMethod `
                    -Method Post `
                    -Uri $localUri `
                    -Headers $headersPowerApi `
                    -Body $body

                $arrInstallStarted.Add($resIntall)
            }
            catch {
                $arrFailedStarts.Add($appToBeInstalled)
            }
        }

        if ($arrFailedStarts.Count -gt 0) {
            $messageString = "The following packages <c='em'>failed to start</c>:"
            Write-PSFMessage -Level Important -Message $messageString
                
            $arrFailedStarts.ToArray()

            if ($arrFailedStarts.Count -eq $D365App.Count) {
                Stop-PSFFunction -Message "Stopping because all package installations failed to start." -Exception $([System.Exception]::new($messageString))
                return
            }
        }
        
        do {
            $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
            $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
        
            $headersPowerApi = @{
                "Authorization" = "Bearer $($tokenPowerApiValue)"
            }

            Start-Sleep -Seconds 60

            $arrStatus = @()

            foreach ($operation in $arrInstallStarted) {
                $localUri = "https://api.powerplatform.com/appmanagement/environments/{0}/operations/{1}?api-version=2022-03-01-preview" `
                    -f $envObj.PpacEnvId `
                    , $operation.lastOperation.operationId

                $resInstallOperation = Invoke-RestMethod `
                    -Method Get `
                    -Uri $localUri `
                    -Headers $headersPowerApi 4> $null

                $arrStatus.Add($resInstallOperation)
            }

            $arrStatus | Format-Table
        } while (
            (-not ("Succeeded" -in $arrStatus.status)) `
                -and
            (-not ("Failed" -in $arrStatus.status))
        )
    }
    
    end {
        
    }
}