
<#
    .SYNOPSIS
        Add application to the list of admin management applications in Power Platform Admin Center (PPAC).
        
    .DESCRIPTION
        Adds an application to the list of admin management applications in Power Platform Admin Center (PPAC).
        This is required for the application to be able to perform certain administrative actions in PPAC, such as managing environments or other applications.
        
    .PARAMETER ServicePrincipalId
        The ID of the service principal to be added to the list of admin management applications.
        
    .EXAMPLE
        PS C:\> Add-PpacAdminManagementApplication -ServicePrincipalId "00000000-0000-0000-0000-000000000000"
        
        This will add the application with the specified service principal ID to the list of admin management applications in PPAC.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
        Based on:
        https://learn.microsoft.com/en-us/power-platform/admin/powerplatform-api-create-service-principal
#>
function Add-PpacAdminManagementApplication {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [string] $ServicePrincipalId
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

        $resAdminApps = @(Invoke-RestMethod -Method Put `
                -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/adminApplications/$($ServicePrincipalId)?api-version=2020-10-01" `
                -Headers $headersBapApi 4> $null)
        
        $resColRaw = $resAdminApps | Select-PSFObject `
            -ExcludeProperty "@odata.etag", "applicationId" `
            -Property "applicationId as appId"

        $resCol = $resColRaw | Select-PSFObject -TypeName "D365Bap.Tools.PpacAdminManagementApplication" `
            -ExcludeProperty "@odata.etag", "appId" `
            -Property "id as ServicePrincipalId",
        "displayName as ServicePrincipalName",
        "appId as AppId",
        "appDisplayName as AppName",
        *
            
        $resCol
    }

    end {
        
    }
}