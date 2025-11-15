
<#
    .SYNOPSIS
        Get users from a Finance and Operations environment.
        
    .DESCRIPTION
        Enables the user to get System Users from a Finance and Operations environment.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentUser -EnvironmentId *uat*
        
        This will list all System Users from the Finance and Operations environment matching the "*uat*" pattern.
        
    .EXAMPLE
        PS C:\> Get-FnOEnvironmentUser -EnvironmentId *uat* -AsExcelOutput
        
        This will list all System Users from the Finance and Operations environment matching the "*uat*" pattern.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FnOEnvironmentUser {
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [switch] $AsExcelOutput
    )
    
    begin {
        # Make sure all *BapEnvironment* cmdlets will validate that the environment exists prior running anything.
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'
        
        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersFnO = @{
            "Authorization" = "Bearer $($tokenFnoOdataValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $localUri = $baseUri + '/data/SystemUsers'
        $resUsers = Invoke-RestMethod -Method Get `
            -Uri $localUri `
            -Headers $headersFnO | Select-Object -ExpandProperty value

        $resCol = @(

            $($resUsers | Sort-Object -Property UserID) | Select-PSFObject -TypeName "D365Bap.Tools.FnOUser" `
                -ExcludeProperty "@odata.etag", "Language", "UserID" `
                -Property "UserID as FnOUserId",
            "UserID as UserId",
            "Company as LegalEntity",
            "UserName as Name",
            "Alias as Upn",
            "UserInfo_language as Language",
            *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-FnOEnvironmentUser"
            return
        }

        $resCol
    }
    
    end {
        
    }
}