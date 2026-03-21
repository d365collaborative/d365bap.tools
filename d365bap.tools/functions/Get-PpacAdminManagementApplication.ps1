
<#
    .SYNOPSIS
        Retrieves information about the Power Platform Admin Management Application(s)
        
    .DESCRIPTION
        Retrieves information about the Power Platform Admin Management Application(s) from the Power Platform Admin API and Microsoft Graph API.
        
    .PARAMETER SkipGraphLookup
        Instructs the function to skip the lookup of the Service Principal in Microsoft Graph API. This will result in faster execution, but will not include details from Microsoft Graph API such as Service Principal Name.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-PpacAdminManagementApplication
        
        This will retrieve all Power Platform Admin Management Applications in the tenant.
        It will perform a lookup in Microsoft Graph API for the applications to retrieve the Service Principal Name.
        
    .EXAMPLE
        PS C:\> Get-PpacAdminManagementApplication -SkipGraphLookup
        
        This will retrieve all Power Platform Admin Management Applications in the tenant.
        It will skip the lookup in Microsoft Graph API.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        Based on:
        https://learn.microsoft.com/en-us/power-platform/admin/powerplatform-api-create-service-principal
#>
function Get-PpacAdminManagementApplication {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [switch] $SkipGraphLookup,

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

        $resAdminApps = Invoke-RestMethod -Method Get `
            -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/adminApplications?api-version=2020-10-01" `
            -Headers $headersBapApi 4> $null | `
            Select-Object -ExpandProperty Value
        
        if ($SkipGraphLookup) {
            $resColRaw = $resAdminApps | Select-PSFObject `
                -ExcludeProperty "@odata.etag", "applicationId" `
                -Property "applicationId as appId"
        }
        else {
            $resColRaw = foreach ($adminApp in $resAdminApps) {
                Get-GraphServicePrincipal -SpId $adminApp.applicationId
            }
        }

        $resCol = $resColRaw | Select-PSFObject -TypeName "D365Bap.Tools.PpacAdminManagementApplication" `
            -ExcludeProperty "@odata.etag", "appId" `
            -Property "id as ServicePrincipalId",
        "displayName as ServicePrincipalName",
        "appId as AppId",
        "appDisplayName as AppName",
        *
            
        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-PpacAdminManagementApplication"
            return
        }

        $resCol
    }

    end {
        
    }
    
}