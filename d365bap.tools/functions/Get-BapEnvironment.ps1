
<#
    .SYNOPSIS
        Get environment info
        
    .DESCRIPTION
        Enables the user to query and validate all environments that are available from inside PPAC
        
        It utilizes the "https://api.bap.microsoft.com" REST API
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
        Default value is "*" - which translates into all available environments
        
    .PARAMETER FnoEnabled
        Instruct the cmdlet to only return environments that have Finance and Operations enabled
        
    .PARAMETER AsExcelOutput
        Instruct the cmdlet to output all details directly to an Excel file
        
        This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment
        
        This will query for ALL available environments.
        It will include both PPAC and FinOps enabled environments.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -FnoEnabled
        
        This will query for ALL available environments.
        It will ONLY include FinOps enabled environments.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6
        
        This will query for the specific environment.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -EnvironmentId *test*
        
        This will query for the specific environment, using a wildcard search.
        
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

        [switch] $FnoEnabled,

        [switch] $AsExcelOutput
    )

    begin {
        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
        
        $resEnvs = Invoke-RestMethod -Method Get `
            -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2023-06-01" `
            -Headers $headersBapApi | `
            Select-Object -ExpandProperty Value

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

                # Flatten properties
                foreach ($prop in $envObj.Properties.PsObject.Properties) {
                    if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
                        $envObj | Add-Member -NotePropertyName "prop_$($prop.Name)" -NotePropertyValue (@(
                                foreach ($inner in $prop.Value.PsObject.Properties) {
                                    "$($inner.Name)=$($inner.Value)"
                                }) -join "`r`n")
                    }
                    else {
                        $envObj | Add-Member -NotePropertyName "prop_$($prop.Name)" -NotePropertyValue $prop.Value -Force
                    }
                }

                foreach ($endPoint in $($envObj.prop_runtimeEndpoints.Split("`r`n")) ) {
                    $keyValue = $endPoint.Replace("microsoft.", "").split("=")
                    $envObj | Add-Member -NotePropertyName "Api.$($keyValue[0])" -NotePropertyValue $keyValue[1] -Force
                }

                $envObj | Select-PSFObject -TypeName "D365Bap.Tools.PpacEnvironment" `
                    -Property "Name as PpacEnvId",
                "Name as EnvId",
                "Location as PpacRegion",
                "prop_tenantId as TenantId",
                "prop_azureRegion as AzureRegion",
                "prop_displayName as PpacEnvName",
                "prop_displayName as EnvName",
                @{Name = "DeployedBy"; Expression = { $_.Properties.createdBy.userPrincipalName } },
                "prop_provisioningState as PpacProvisioningState",
                "prop_environmentSku as PpacEnvSku",
                "prop_environmentSku as Sku",
                "prop_databaseType as PpacDbType",
                "prop_creationType as PpacCreationType",
                "Properties.linkedAppMetadata.id as LinkedAppLcsEnvId",
                "Properties.linkedAppMetadata.url as LinkedAppLcsEnvUri",
                "Properties.linkedEnvironmentMetadata.resourceId as LinkedMetaPpacOrgId",
                "Properties.linkedEnvironmentMetadata.uniqueName as LinkedMetaPpacUniqueId",
                @{Name = "LinkedMetaPpacEnvUri"; Expression = { $_.Properties.linkedEnvironmentMetadata.instanceUrl -replace "com/", "com" } },
                @{Name = "LinkedMetaPpacEnvApiUri"; Expression = { $_.Properties.linkedEnvironmentMetadata.instanceApiUrl -replace "com/", "com" } },
                "Properties.linkedEnvironmentMetadata.baseLanguage as LinkedMetaPpacEnvLanguage",
                "Properties.cluster.uriSuffix as PpacClusterIsland",
                "Properties.linkedAppMetadata.type as FinOpsMetadataEnvType",
                "Properties.linkedAppMetadata.url as FinOpsMetadataEnvUri",
                @{Name = "PpacManagedEnv"; Expression = { $_.Properties.governanceConfiguration.protectionLevel -ne 'Basic' } },
                @{Name = "Managed"; Expression = { $_.Properties.governanceConfiguration.protectionLevel -ne 'Basic' } },
                @{Name = "FnOEnvUri"; Expression = { $_.Properties.linkedAppMetadata.url -replace "com/", "com" } },
                @{Name = "FinOpsEnvUri"; Expression = { $_.Properties.linkedAppMetadata.url -replace "com/", "com" } },
                @{Name = "PpacEnvUri"; Expression = { $_.Properties.linkedEnvironmentMetadata.instanceUrl -replace "com/", "com" } },
                @{Name = "PpacEnvApiUri"; Expression = { $_.Properties.linkedEnvironmentMetadata.instanceApiUrl -replace "com/", "com" } },
                @{Name = "AdminMode"; Expression = { $_.Properties.states.runtime.id -eq "AdminMode" } },
                @{Name = "State"; Expression = {
                        if ($_.Properties.states.management.id -eq 'NotSpecified') {
                            $_.Properties.linkedEnvironmentMetadata.instanceState
                        }
                        else {
                            $_.Properties.states.management.id
                        }
                    }
                },
                @{Name = "FnOEnvType"; Expression = {
                        $uri = $_.Properties.linkedAppMetadata.url
                        switch ($_.Properties.linkedAppMetadata.type) {
                            "Internal" { "UDE/USE" }
                            "Linked" {
                                if ($uri -like "*axcloud*") {
                                    "LcsDevbox"
                                }
                                elseif ($uri -like "*sandbox*") {
                                    "LcsSandbox"
                                }
                                else {
                                    "LcsProduction"
                                }
                            }
                            Default { "N/A" }
                        }
                    }
                },
                *
            }
        )

        if ($FnoEnabled) {
            $resCol = $resCol | Where-Object { $null -ne $_.FinOpsMetadataEnvType }
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-BapEnvironment" `
                -NoNumberConversion Version, AvailableVersion, InstalledVersion, crmMinversion, crmMaxVersion, Version
            return
        }

        $resCol
    }
    
    end {
        
    }
}