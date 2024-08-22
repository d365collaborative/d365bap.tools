
<#
    .SYNOPSIS
        Get environment info
        
    .DESCRIPTION
        Enables the user to query and validate all environments that are available from inside PPAC
        
        It utilizes the "https://api.bap.microsoft.com" REST API
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        Default value is "*" - which translates into all available environments
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment
        
        This will query for ALL available environments.
        
        Sample output:
        PpacEnvId                            PpacEnvRegion   PpacEnvName          PpacEnvSku LinkedAppLcsEnvUri
        ---------                            -------------   -----------          ---------- ------------------
        32c6b196-ef52-4c43-93cf-6ecba51e6aa1 europe          new-uat              Sandbox    https://new-uat.sandbox.operatio...
        eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 europe          new-test             Sandbox    https://new-test.sandbox.operati...
        d45936a7-0408-4b79-94d1-19e4c6e5a52e europe          new-golden           Sandbox    https://new-golden.sandbox.opera...
        Default-e210bc90-e54b-4544-a9b8-b123 europe          New Customer         Default
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will query for the specific environment.
        
        Sample output:
        PpacEnvId                            PpacRegion      PpacName             PpacSku    LinkedAppLcsEnvUri
        ---------                            -------------   -----------          ---------- ------------------
        eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 europe          new-test             Sandbox    https://new-test.sandbox.operati...
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -EnvironmentId *test*
        
        This will query for the specific environment, using a wildcard search.
        
        Sample output:
        PpacEnvId                            PpacRegion      PpacName             PpacSku    LinkedAppLcsEnvUri
        ---------                            -------------   -----------          ---------- ------------------
        eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 europe          new-test             Sandbox    https://new-test.sandbox.operati...
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -AsExcelOutput
        
        This will query for ALL available environments.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironment {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [string] $EnvironmentId = "*",

        [switch] $AsExcelOutput
    )

    begin {
        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headers = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
        
        $resEnvs = Invoke-RestMethod -Method Get -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2023-06-01" -Headers $headers | Select-Object -ExpandProperty Value

        $searchById = Test-Guid -InputObject $EnvironmentId
    }
    
    process {
        $resCol = @(
            foreach ($envObj in $resEnvs) {
                if ($searchById) {
                    # Name is the GUID
                    if (-not ($envObj.Name -like $EnvironmentId)) { continue }
                }
                else {
                    # DisplayName is the name
                    if (-not ($envObj.properties.displayName -like $EnvironmentId)) { continue }
                }
                
                # $envObj | ConvertTo-Json -depth 10

                $res = [ordered]@{}

                $res.Id = $envObj.Name
                $res.Region = $envObj.Location
            
                foreach ($prop in $envObj.Properties.PsObject.Properties) {
                    if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
                        $res."prop_$($prop.Name)" = @(
                            foreach ($inner in $prop.Value.PsObject.Properties) {
                                "$($inner.Name)=$($inner.Value)"
                            }) -join "`r`n"
                    }
                    else {
                        $res."prop_$($prop.Name)" = $prop.Value
                    }
                
                }

            ([PSCustomObject]$res) | Select-PSFObject -TypeName "D365Bap.Tools.PpacEnvironment" `
                    -Property "Id as PpacEnvId",
                "Region as PpacEnvRegion",
                "prop_tenantId as TenantId",
                "prop_azureRegion as AzureRegion",
                "prop_displayName as PpacEnvName",
                @{Name = "DeployedBy"; Expression = { $envObj.Properties.createdBy.userPrincipalName } },
                "prop_provisioningState as PpacProvisioningState",
                "prop_environmentSku as PpacEnvSku",
                "prop_databaseType as PpacDbType",
                @{Name = "LinkedAppLcsEnvId"; Expression = { $envObj.Properties.linkedAppMetadata.id } },
                @{Name = "LinkedAppLcsEnvUri"; Expression = { $envObj.Properties.linkedAppMetadata.url } },
                @{Name = "LinkedMetaPpacOrgId"; Expression = { $envObj.Properties.linkedEnvironmentMetadata.resourceId } },
                @{Name = "LinkedMetaPpacUniqueId"; Expression = { $envObj.Properties.linkedEnvironmentMetadata.uniqueName } },
                @{Name = "LinkedMetaPpacEnvUri"; Expression = { $envObj.Properties.linkedEnvironmentMetadata.instanceUrl -replace "com/", "com" } },
                @{Name = "LinkedMetaPpacEnvApiUri"; Expression = { $envObj.Properties.linkedEnvironmentMetadata.instanceApiUrl -replace "com/", "com" } },
                @{Name = "LinkedMetaPpacEnvLanguage"; Expression = { $envObj.Properties.linkedEnvironmentMetadata.baseLanguage } },
                @{Name = "PpacClusterIsland"; Expression = { $envObj.Properties.cluster.uriSuffix } },
                "*"
            }
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -NoNumberConversion Version, AvailableVersion, InstalledVersion, crmMinversion, crmMaxVersion, Version
            return
        }

        $resCol
    }
    
    end {
        
    }
}