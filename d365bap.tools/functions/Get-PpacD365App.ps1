
<#
    .SYNOPSIS
        Get D365 application that are available in the environment.
        
    .DESCRIPTION
        Retrieves available D365 applications from the environment as they are shown in the Power Platform Admin Center (PPAC).
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER Name
        Name of the D365 application that you want to retrieve.
        
        Wildcards are accepted, and it will search in both the application name and the unique name for a match.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to output the results as an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacD365App -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6"
        
        This will fetch all D365 applications from the environment.
        
    .EXAMPLE
        PS C:\> Get-PpacD365App -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Name "*invoice*"
        
        This will fetch all D365 applications from the environment.
        It will filter the results to only include applications that have "invoice" in either the application name or the unique name.
        
    .EXAMPLE
        PS C:\> Get-PpacD365App -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -AsExcelOutput
        
        This will fetch all D365 applications from the environment.
        It will output the results directly into an Excel file, that will automatically open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacD365App {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter (Mandatory = $true)]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $AsExcelOutput
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
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        # First we will fetch ALL available apps for the environment
        $secureTokenPowerApi = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com/" -AsSecureString).Token
        $tokenPowerApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenPowerApi
        
        $headersPowerApi = @{
            "Authorization"    = "Bearer $($tokenPowerApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal" # minimal || full
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }
        
        $appsAvailable = Invoke-RestMethod `
            -Method Get `
            -Uri "https://api.powerplatform.com/appmanagement/environments/$($envObj.PpacEnvId)/applicationPackages?api-version=2022-03-01-preview" `
            -Headers $headersPowerApi | `
            Select-Object -ExpandProperty Value
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $colApps = $appsAvailable | Where-Object {
            ($_.ApplicationName -like $Name -or $_.ApplicationName -eq $Name) `
                -or ($_.UniqueName -like $Name -or $_.UniqueName -eq $Name)
        } | Sort-Object -Property ApplicationName

        $resCol = $colApps | Select-PSFObject -TypeName "D365Bap.Tools.BapD365App" `
            -Property "Id as PpacD365AppId",
        "ApplicationName as PpacD365AppName",
        "UniqueName as PpacPackageName",
        "Version as AvailableVersion",
        "state as Status",
        @{Name = "StateIsInstalled"; Expression = { if (($_.state -ne 'none')) { $true } else { $false } } },
        *,
        @{Name = "SupportedCountriesList"; Expression = { $_.supportedCountries -join "," } }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacD365App" `
                -NoNumberConversion Version, AvailableVersion, InstalledVersion, crmMinversion, crmMaxVersion, Version
            return
        }

        $resCol
    }
    
    end {
        
    }
}