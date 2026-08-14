
<#
    .SYNOPSIS
        Start the publish all customizations process for a given environment.
        
    .DESCRIPTION
        This cmdlet starts the publish all customizations process for a given Power Platform environment.
        
        Can be helpful to run this cmdlet after importing a solution to make sure all customizations are published and ready to use.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .EXAMPLE
        PS C:\> Invoke-PpePublishAllCustomizations -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
        
        This will start the publish all customizations process for the environment with the id "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6".
        It will fail if any internal error occurs during the publish process, otherwise it will complete silently.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Invoke-PpePublishAllCustomizations {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    param (
        [parameter (Mandatory = $true)]
        [string] $EnvironmentId
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
        
        $baseUri = $envObj.PpacEnvUri

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
            "Content-Type"  = "application/json;charset=utf-8"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $localUri = $baseUri + "/api/data/v9.0/PublishAllXml"

        Invoke-RestMethod -Method Post `
            -Uri $localUri `
            -Headers $headersWebApi `
            -ContentType $headersWebApi."Content-Type" `
            -StatusCodeVariable statusPublish 4> $null

        if (-not ($statusPublish -like "2*")) {
            $messageString = "Failed to publish all customizations for the environment. Please check the environment and try publishing manually via the Power Platform make portal - <c='em'>https://make.powerapps.com</c>"
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because publish all customizations failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
    }
    
    end {
        
    }
}