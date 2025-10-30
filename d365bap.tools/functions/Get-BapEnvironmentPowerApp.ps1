
<#
    .SYNOPSIS
        Get PowerApps from environment
        
    .DESCRIPTION
        Enables the user to fetch all PowerApps from the environment
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        This can be obtained from the Get-BapEnvironment cmdlet
        
        Wildcard is supported
        
    .PARAMETER Name
        Name of the Power App that you are looking for
        
        It supports wildcard searching, which is validated against the following properties:
        * PpacPowerAppName / Name / DisplayName / PpacSystemName
        * PpacPowerAppName / LogicalName / UniqueName
        
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentPowerApp -EnvironmentId *uat*
        
        This will query the environment for ALL available Power Apps.
        It will show both Canvas and Model-driven apps.
        
        Sample output:
        PpacPowerAppName               PowerAppType IsManaged Owner                Description
        ----------------               ------------ --------- -----                -----------
        API Playground                 Canvas       True      alex@contoso.com
        Channel Integration Framework  Model-driven True      N/A                  Bring your communication channels and bu...
        CRM Hub                        Model-driven True      N/A                  Mobile app that provides core CRM functi...
        Customer Service admin center  Model-driven True      N/A                  A unified app for customer service admin...
        Customer Service Hub           Model-driven True      N/A                  A focused, interactive experience for ma...
        Customer Service workspace     Model-driven True      N/A                  Multi-session Customer Service with Prod...
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentPowerApp -EnvironmentId *uat* -Name *CRM*
        
        This will query the environment for ALL available Power Apps.
        It will show both Canvas and Model-driven apps.
        It will only show those that has "CRM" in the name.
        
        Sample output:
        PpacPowerAppName               PowerAppType IsManaged Owner                Description
        ----------------               ------------ --------- -----                -----------
        CRM Hub                        Model-driven True      N/A                  Mobile app that provides core CRM functi...
        
        
    .EXAMPLE
        PS C:\> Get-BapEnvironmentPowerApp -EnvironmentId *uat* -AsExcelOutput
        
        This will query the environment for ALL available Power Apps.
        It will show both Canvas and Model-driven apps.
        It will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironmentPowerApp {
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
        $envObj = Get-BapEnvironment -EnvironmentId $EnvironmentId | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "The supplied EnvironmentId: <c='em'>$EnvironmentId</c> didn't return any matching environment details. Please verify that the EnvironmentId is correct - try running the <c='em'>Get-BapEnvironment</c> cmdlet."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
        }
        
        if (Test-PSFFunctionInterrupt) { return }

        $baseUri = $envObj.LinkedMetaPpacEnvUri
        $uriPowerAppsApi = $envObj."Api.PowerApps"

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headersWebApi = @{
            "Authorization" = "Bearer $($tokenWebApiValue)"
        }

        # Work around for getting the user id
        $extObj = (Get-AzContext | Select-Object -ExpandProperty account).ExtendedProperties
        $curEntraUserId = $extObj.HomeAccountId.Replace(".$($extObj.Tenants)", "")

        $expandPermissions = "permissions(`$filter=maxAssignedTo(`'$curEntraUserId`'))"

        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        # Model-driven Apps - needs to be fetched directly against the WebAPI on the environment
        $localUri = $baseUri + '/api/data/v9.0/appmodules/Microsoft.Dynamics.CRM.RetrieveUnpublishedMultiple()?$select=appmoduleid,name,uniquename,modifiedon,createdon,_createdby_value,publishedon,componentstate,ismanaged,webresourceid,description,statecode,aiappdescription'
        $resModelApps = Invoke-RestMethod -Method Get -Uri $localUri -Headers $headersWebApi

        $resColModelApps = @(
            foreach ($appObj in  $($resModelApps.value)) {
                if ((-not ($appObj.name -like $Name -or $appObj.name -eq $Name)) -and (-not ($appObj.uniquename -like $Name -or $appObj.uniquename -eq $Name))) { continue }

                $appObj | Select-PSFObject -TypeName "D365Bap.Tools.PpacPowerApp" `
                    -ExcludeProperty "@odata.etag" `
                    -Property "name as DisplayName",
                @{ Name = "PpacPowerAppName"; Expression = { $_.name } },
                @{ Name = "PowerAppType"; Expression = { 'Model-driven' } },
                "uniquename as PpacSystemName",
                "appmoduleid as PpacAppModuleId",
                @{ Name = "DvAppModuleId"; Expression = { $_.appmoduleid } },
                @{ Name = "Owner"; Expression = { 'N/A' } },
                *
            })


        # Canvas Apps - needs to be fetched against the PowerApps API
        $localUri = "$uriPowerAppsApi/providers/Microsoft.PowerApps/scopes/admin/environments/$($envObj.PpacEnvId)/apps?api-version=2016-11-01&`$expand=$expandPermissions"
        $resCanvasApps = Invoke-RestMethod -Method Get -Uri $localUri -Headers $headersBapApi

        $resColCanvasApps = @(
            foreach ($appObj in  $($resCanvasApps.value)) {
                if ((-not ($appObj.properties.displayName -like $Name -or $appObj.properties.displayName -eq $Name)) -and (-not ($appObj.logicalName -like $Name -or $appObj.logicalName -eq $Name))) { continue }

                $appObj | Select-PSFObject -TypeName "D365Bap.Tools.PpacPowerApp" `
                    -ExcludeProperty "@odata.etag" `
                    -Property @{ Name = "DisplayName"; Expression = { $_.properties.displayName } },
                @{ Name = "PpacPowerAppName"; Expression = { $_.properties.displayName } },
                @{ Name = "PowerAppType"; Expression = { 'Canvas' } },
                "logicalName as PpacSystemName",
                "id as PpacAppModuleId",
                @{ Name = "DvAppModuleId"; Expression = { $_.logicalName } },
                @{ Name = "Owner"; Expression = { $_.properties.owner.email } },
                @{ Name = "IsManaged"; Expression = { $true } },
                @{ Name = "Description"; Expression = { $_.properties.description } },
                *
            })

        $resCol = @( $resColModelApps + $resColCanvasApps ) | Sort-Object -Property DisplayName

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-BapEnvironmentPowerApp"
            return
        }

        $resCol
    }
    
    end {
        
    }
}