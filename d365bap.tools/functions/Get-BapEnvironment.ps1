
<#
    .SYNOPSIS
        Retrieves information about Power Platform environments.
        
    .DESCRIPTION
        This function retrieves information about Power Platform environments from the Power Platform Admin Center (PPAC).
        
        It allows filtering by environment ID, checking for Finance and Operations enabled environments, and exporting the results to Excel.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against.
        
        Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.
        
    .PARAMETER FscmEnabled
        Instructs the function to only return environments that have Dynamics 365 ERP suite capabilities (environments that is either linked or provisioned as an unified environment).
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment
        
        This will return all environments in the Power Platform tenant.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -EnvironmentId "env-123"
        
        This will return the environment with the id "env-123".
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -FscmEnabled
        
        This will return all environments in the Power Platform tenant that have Dynamics 365 ERP suite capabilities.
        
    .EXAMPLE
        PS C:\> Get-BapEnvironment -FscmEnabled -AsExcelOutput
        
        This will return all environments in the Power Platform tenant that have Dynamics 365 ERP suite capabilities.
        It will export the results to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-BapEnvironment {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (
        [string] $EnvironmentId = "*",

        [switch] $FscmEnabled,

        [switch] $AsExcelOutput
    )

    begin {
        $secureTokenBap = (Get-AzAccessToken -ResourceUrl "https://service.powerapps.com/" -AsSecureString -ErrorAction Stop).Token
        $tokenBapValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureTokenBap

        $headersBapApi = @{
            "Authorization" = "Bearer $($tokenBapValue)"
        }
        
        $colEnvsRaw = Invoke-RestMethod -Method Get `
            -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2023-06-01" `
            -Headers $headersBapApi 4> $null | `
            Select-Object -ExpandProperty Value
    }
    
    process {
        $colEnvs = $colEnvsRaw | Where-Object {
            ($_.Name -like $EnvironmentId -or $_.Name -eq $EnvironmentId) `
                -or ($_.properties.displayName -like $EnvironmentId `
                    -or $_.properties.displayName -eq $EnvironmentId) `
                -or ($_.Properties.linkedAppMetadata.id -like $EnvironmentId `
                    -or $_.Properties.linkedAppMetadata.id -eq $EnvironmentId)
        }
        
        if ($FscmEnabled) {
            $colEnvs = $colEnvs | Where-Object { $null -ne $_.Properties.linkedAppMetadata.type }
        }
            
        $resColRaw = @(
            foreach ($envObj in $colEnvs) {
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

                $envObj
            }
        )

        $resCol = $resColRaw | Select-PSFObject -TypeName "D365Bap.Tools.PpacEnvironment" `
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
        "Properties.linkedEnvironmentMetadata.securityGroupId as SecurityGroupId",
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
        @{Name = "EnvType"; Expression = {
                $uri = $_.Properties.linkedAppMetadata.url;
                switch ($_.Properties.linkedAppMetadata.type) {
                    "Internal" { "Unified" }
                    "Linked" {
                        if ($uri -like "*axcloud*" -or $uri -like "*cloudax*") {
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