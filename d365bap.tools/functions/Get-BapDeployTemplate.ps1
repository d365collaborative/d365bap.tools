
<#
    .SYNOPSIS
        Get the available deployment templates for a specific location
        
    .DESCRIPTION
        Retrieves the list of available deployment templates for Power Platform environments in a specified location.
        
        Includes details such as template name, SKU, and whether it is disabled.
        
    .PARAMETER Location
        Specifies the location for which to retrieve deployment templates.
        
    .PARAMETER Name
        Filter the deployment templates by name or ID.
        
        Supports wildcard characters (*).
        
    .PARAMETER Sku
        Filter the deployment templates by SKU.
        Valid values are "All", "Developer", "Sandbox", "Trial", "SubscriptionBasedTrial", "Production", and "Default".
        
    .PARAMETER FnoOnly
        Instructs the cmdlet to only return Finance and Operations related templates.
        
        
    .PARAMETER IncludeDisabled
        Instructs the cmdlet to include disabled deployment templates in the output.
        
    .PARAMETER AsExcelOutput
        Instructs the cmdlet to export the output to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-BapDeployTemplate -Location "Europe"
        
        This will retrieve all available deployment templates for Power Platform environments in the "Europe" location.
        
    .EXAMPLE
        PS C:\> Get-BapDeployTemplate -Location "Europe" -Name "*d365*"
        
        This will retrieve all d365 related deployment templates in the "Europe" location.
        
    .EXAMPLE
        PS C:\> Get-BapDeployTemplate -Location "Europe" -Sku "Sandbox"
        
        This will retrieve all sandbox deployment templates in the "Europe" location.
        
    .EXAMPLE
        PS C:\> Get-BapDeployTemplate -Location "Europe" -FnoOnly
        
        This will retrieve all Finance and Operations related deployment templates in the "Europe" location.
        
    .EXAMPLE
        PS C:\> Get-BapDeployTemplate -Location "Europe" -IncludeDisabled
        
        This will retrieve all deployment templates, including disabled ones, in the "Europe" location.
        
    .EXAMPLE
        PS C:\> Get-BapDeployTemplate -Location "Europe" -AsExcelOutput
        
        This will retrieve all available deployment templates for Power Platform environments in the "Europe" location and export the output to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapDeployTemplate {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Location,

        [string] $Name = "*",

        [ValidateSet("All", "Developer", "Sandbox", "Trial", "SubscriptionBasedTrial", "Production", "Default")]
        [string] $Sku = "All",

        [switch] $FnoOnly,

        [switch] $IncludeDisabled,

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

        $resTemplates = Invoke-RestMethod -Method Get `
            -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/locations/$Location/templates?api-version=2020-05-01" `
            -Headers $headersBapApi
        
        $resCol = @(
            foreach ($prop in $resTemplates.PsObject.Properties) {
                if ($null -eq $prop.Value) { continue }
            
                $prop.Value | Select-PSFObject -TypeName "D365Bap.Tools.DeployTemplate" `
                    -ExcludeProperty "location", "name", "properties" `
                    -Property "name as Id",
                "id as ResourceId",
                "location as Location",
                @{Name = "Type"; Expression = { $prop.Name } },
                @{Name = "Sku"; Expression = { $prop.Name } },
                "properties.displayName as Name",
                "properties.isDisabled as IsDisabled",
                "properties.isCustomerEngagement as IsCrm",
                "properties.isCustomerEngagement as IsCustomerEngagement",
                "properties.isSupportedForResetOperation as ResetSupported",
                "properties.isSupportedForResetOperation as IsSupportedForResetOperation",
                "properties as Properties"
            }
        )

        $resCol = $resCol | Where-Object { `
                $_.Name -like $Name `
                -or $_.Id -like $Name
        }

        if ($FnoOnly) {
            $resCol = $resCol | Where-Object { $_.Id -like "*FinOps*" }
        }
        
        if ($Sku -ne "All") {
            $resCol = $resCol | Where-Object { $_.Sku -eq $Sku }
        }

        if (-not $IncludeDisabled) {
            $resCol = $resCol | Where-Object { -not $_.IsDisabled }
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-BapDeployTemplate" `
                -WarningAction SilentlyContinue
            return
        }

        $resCol
    }
    
    end {
        
    }
}