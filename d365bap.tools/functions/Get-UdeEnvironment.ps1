<#
.SYNOPSIS
Gets UDE environments.

.DESCRIPTION
This function retrieves UDE environments.

.PARAMETER EnvironmentId
The ID of the environment to retrieve.

Supports wildcard patterns.

Can be either the environment name or the environment GUID.

.PARAMETER SkipVersionDetails
Instructs the function to skip retrieving version details.

Will result in faster execution.

.PARAMETER AsExcelOutput
Instructs the function to export the results to an Excel file.

.EXAMPLE
PS C:\> Get-UdeEnvironment

This will retrieve all available UDE environments.

.EXAMPLE
PS C:\> Get-UdeEnvironment -EnvironmentId "env-123"

This will retrieve the UDE environment with the specified environment ID.

.EXAMPLE
PS C:\> Get-UdeEnvironment -SkipVersionDetails

This will retrieve all available UDE environments without version details.

.EXAMPLE
PS C:\> Get-UdeEnvironment -AsExcelOutput

This will export the retrieved UDE environments to an Excel file.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeEnvironment {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [string] $EnvironmentId = "*",

        [switch] $SkipVersionDetails,

        [switch] $AsExcelOutput
    )

    begin {
        $colEnv = Get-BapEnvironment -EnvironmentId $EnvironmentId

        $searchById = Test-Guid -InputObject $EnvironmentId

        $currentProgress = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }
    
    process {
        $SoapBody = @"
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
    <s:Header>
        <UserType xmlns="http://schemas.microsoft.com/xrm/2011/Contracts">CrmUser</UserType>
        <SdkClientVersion xmlns="http://schemas.microsoft.com/xrm/2011/Contracts">9.2.49.6961</SdkClientVersion>
        <x-ms-client-request-id xmlns="http://schemas.microsoft.com/xrm/2011/Contracts">##REQUESTID##</x-ms-client-request-id>
    </s:Header>
    <s:Body>
        <Execute xmlns="http://schemas.microsoft.com/xrm/2011/Contracts/Services">
            <request xmlns:a="http://schemas.microsoft.com/xrm/2011/Contracts" xmlns:i="http://www.w3.org/2001/XMLSchema-instance">
                <a:Parameters xmlns:b="http://schemas.datacontract.org/2004/07/System.Collections.Generic"/>
                <a:RequestId>##REQUESTID##</a:RequestId>
                <a:RequestName>msprov_getfinopsapplicationdetails</a:RequestName>
            </request>
        </Execute>
    </s:Body>
</s:Envelope>
"@
        
        $resCol = @(
            foreach ($envObj in $($colEnv | Where-Object FinOpsMetadataEnvType -eq "Internal")) {
                if ($searchById) {
                    # Name is the GUID
                    if (-not ($envObj.Id -like $EnvironmentId)) { continue }
                }
                else {
                    # DisplayName is the name
                    if (-not ($envObj.PpacEnvName -like $EnvironmentId)) { continue }
                }

                if ($SkipVersionDetails) {
                    $envObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironmentBasic" `
                        -Property "LinkedAppLcsEnvUri as FinOpsEnvUri",
                    "LinkedMetaPpacEnvUri as PpacEnvUri",
                    *

                    continue
                }

                # We need to get the internal provisioning details via SOAP call
                $baseUri = $envObj.LinkedMetaPpacEnvUri
                $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
                $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
        
                $payload = $SoapBody -replace "##REQUESTID##", ([System.Guid]::NewGuid().ToString())
                $localUri = "$($baseUri)/XRMServices/2011/Organization.svc/web?SDKClientVersion=9.2.49.6961"

                $headers = @{
                    "Content-Type"  = "text/xml; charset=utf-8"
                    "Authorization" = "Bearer $($tokenWebApiValue)"
                    "Soapaction"    = "http://schemas.microsoft.com/xrm/2011/Contracts/Services/IOrganizationService/Execute"
                }

                $Response = Invoke-WebRequest -Uri $localUri `
                    -Method Post `
                    -Headers $headers `
                    -Body $payload `
                    -UseBasicParsing

                $tmpXml = [xml]$Response.Content
                $nodes = $tmpXml.SelectNodes('//*[local-name()="KeyValuePairOfstringanyType"]')

                foreach ($node in $nodes) {
                    $keyNode = $node.SelectSingleNode('*[local-name()="key"]')
                    $valueNode = $node.SelectSingleNode('*[local-name()="value"]')

                    $propName = $($keyNode.InnerText).Replace("applicationversion", "AppVersion").Replace("platformversion", "PlatVersion").Replace("finopsenvironmentstate", "State").Replace("applicationdeploymenttype", "Type").Replace("finopsenvironmentid", "Id")
                    $envObj | Add-Member -NotePropertyName "Provisioning$($propName)" -NotePropertyValue $valueNode.InnerText
                }

                # We need to user friendly version details from the installed D365 app
                $appProvision = Get-BapEnvironmentD365App -EnvironmentId $envObj.Id `
                    -Status Installed `
                    -Name msdyn_FinanceAndOperationsProvisioningAppAnchor | `
                    Select-Object -First 1

                $envObj | Add-Member -NotePropertyName "FinOpsApp" -NotePropertyValue $appProvision.InstalledVersion

                $envObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironment" `
                    -Property "ProvisioningAppVersion as PpacProvApp",
                "ProvisioningPlatVersion as PpacProvPlatform",
                "ProvisioningState as PpacProvState",
                "ProvisioningType as PpacProvType",
                "LinkedAppLcsEnvUri as FinOpsEnvUri",
                "LinkedMetaPpacEnvUri as PpacEnvUri", *
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }
    
    end {
        $ProgressPreference = $currentProgress
    }
}