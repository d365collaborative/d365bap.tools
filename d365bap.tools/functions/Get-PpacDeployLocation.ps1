
<#
    .SYNOPSIS
        Get the available deployment locations for Power Platform environments.
        
    .DESCRIPTION
        Retrieves the list of available deployment locations where Power Platform environments can be provisioned.
        
        Includes details such as location name and azure regions.
        
    .PARAMETER Name
        Filter the deployment locations by name or ID.
        
        Supports wildcard characters (*).
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the output to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacDeployLocation
        
        This will retrieve all available deployment locations for Power Platform environments.
        
    .EXAMPLE
        PS C:\> Get-PpacDeployLocation -Name "Europe"
        
        This will retrieve the deployment location "Europe".
        
    .EXAMPLE
        PS C:\> Get-PpacDeployLocation -AsExcelOutput
        
        This will retrieve all available deployment locations and export the output to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-PpacDeployLocation {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [string] $Name = "*",

        [switch] $AsExcelOutput
    )

    begin {
        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }

        $colLocations = Invoke-RestMethod -Method Get `
            -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/locations?api-version=2021-04-01" `
            -Headers $headersBapApi | `
            Select-Object -ExpandProperty Value
        
        $resCol = @(
            $colLocations | Select-PSFObject -TypeName "D365Bap.Tools.BapLocation" `
                -ExcludeProperty "id", "type", "name", "properties" `
                -Property "name as Id",
            "properties.displayName as Name",
            "properties.code as Code",
            "properties.isDisabled as IsDisabled",
            "properties.canProvisionDatabase as CanProvisionDb",
            "properties.canProvisionCustomerEngagementDatabase as CanProvisionCrmDb",
            "properties.hasFirstReleaseIslandAvailableForProvisioning as HasFirstReleaseProvisioning",
            "properties.azureRegions as AzureRegions",
            @{Name = "AzureRegionsList"; Expression = { ($_.properties.azureRegions -join ", ") } },
            "properties as Properties"
        )

        $resCol = $resCol | Where-Object { `
                $_.Name -like $Name `
                -or $_.Id -like $Name
        }
        
        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacDeployLocation" `
                -WarningAction SilentlyContinue
            return
        }

        $resCol
    }
    
    end {
        
    }
}