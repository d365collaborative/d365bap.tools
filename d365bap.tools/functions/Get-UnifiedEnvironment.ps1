
<#
    .SYNOPSIS
        Get Unified Environment in Power Platform Admin Center (PPAC).
        
    .DESCRIPTION
        Retrieves information about Unified Environments in Power Platform Admin Center (PPAC).
        
Support D365 Finance and Operations, either Developer Edition (UDE) or Unified Sandbox Environment (USE).
        
    .PARAMETER EnvironmentId
        The ID of the environment to retrieve.
        
        Supports wildcard patterns.
        
        Can be either the environment name or the environment GUID.
        
    .PARAMETER SkipVersionDetails
        Instructs the function to skip retrieving version details.
        
        Will result in faster execution, but will not include version information and tell you if the environment is UDE or USE.
        
    .PARAMETER UdeOnly
        Instructs the function to only return UDE environments.
        
    .PARAMETER UseOnly
        Instructs the function to only return USE environments.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment
        
        This will retrieve all available UDE/USE environments.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -EnvironmentId "env-123"
        
        This will retrieve the UDE/USE environment with the specified environment ID.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -SkipVersionDetails
        
        This will retrieve all available UDE/USE environments without version details.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -UdeOnly
        
        This will retrieve only UDE environments.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -UseOnly
        
        This will retrieve only USE environments.
        
    .EXAMPLE
        PS C:\> Get-UnifiedEnvironment -AsExcelOutput
        
        This will export the retrieved UDE/USE environments to an Excel file.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UnifiedEnvironment {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType('System.Object[]')]
    param (
        [Parameter()]
        [string] $EnvironmentId = "*",

        [Parameter(ParameterSetName = "SkipVersion")]
        [switch] $SkipVersionDetails,

        [Parameter(ParameterSetName = "UdeOnly")]
        [switch] $UdeOnly,
        
        [Parameter(ParameterSetName = "UseOnly")]
        [switch] $UseOnly,

        [Parameter()]
        [switch] $AsExcelOutput
    )

    begin {
        $colEnv = Get-BapEnvironment -EnvironmentId $EnvironmentId `
            -FnoEnabled

        $searchById = Test-Guid -InputObject $EnvironmentId

        $currentProgress = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }
    
    process {
        $filteredEnvs = $colEnv | Where-Object FinOpsMetadataEnvType -eq "Internal"

        $resCol = $filteredEnvs | ForEach-Object -Parallel {
            $envObj = $_

            if ($using:searchById) {
                if (-not ($envObj.PpacEnvId -like $using:EnvironmentId)) { continue }
            }
            else {
                if (-not ($envObj.PpacEnvName -like $using:EnvironmentId)) { continue }
            }

            if ($using:SkipVersionDetails) {
                $envObj

                continue
            }

            # Import required modules inside the parallel block if they are not automatically loaded
            # Adjust as needed based on your environment/module setup
            Import-Module Az.Accounts -ErrorAction SilentlyContinue
            Import-Module PSFramework -ErrorAction SilentlyContinue

            # We need to get the internal provisioning details via SOAP call
            $baseUri = $envObj.PpacEnvUri
            $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
            $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken
        
            $headers = @{
                "Authorization" = "Bearer $($tokenWebApiValue)"
            }

            $localUri = $baseUri + '/api/data/v9.2/msprov_getfinopsapplicationdetails'

            $Response = Invoke-RestMethod -Uri $localUri `
                -Method Get `
                -Headers $headers `
                -SkipHttpErrorCheck

            if ($null -eq $Response) {
                $messageString = "Could not obtain the <c='em'>Ppac Provision</c> details for <c='em'>$($envObj.PpacEnvName)</c>. It could be due to insufficient permissions or the environment not being fully provisioned. Please try to access the environment details from PowerPlatform Admin Center (PPAC)."
                Write-PSFMessage -Level Important -Message $messageString
                Write-PSFHostColor -String "- <c='em'>https://admin.powerplatform.microsoft.com/environments/environment/$($envObj.PpacEnvId)/hub</c>"
            }
            else {
                $envObj | Add-Member -NotePropertyName "ProvisioningAppVersion" -NotePropertyValue $Response.applicationversion
                $envObj | Add-Member -NotePropertyName "ProvisioningPlatVersion" -NotePropertyValue $Response.platformversion
                $envObj | Add-Member -NotePropertyName "ProvisioningState" -NotePropertyValue $Response.finopsenvironmentstate
                $envObj | Add-Member -NotePropertyName "ProvisioningType" -NotePropertyValue $Response.applicationdeploymenttype
            }

            # We need to user friendly version details from the installed D365 app
            $appProvision = Get-BapEnvironmentD365App -EnvironmentId $envObj.PpacEnvId `
                -Status Installed `
                -Name msdyn_FinanceAndOperationsProvisioningAppAnchor | `
                Select-Object -First 1

            $envObj | Add-Member -NotePropertyName "FinOpsApp" -NotePropertyValue $appProvision.InstalledVersion

            $envObj | Select-PSFObject -TypeName "D365Bap.Tools.UdeEnvironment" `
                -ExcludeProperty FnOEnvType `
                -Property "ProvisioningAppVersion as PpacProvApp",
            "ProvisioningPlatVersion as PpacProvPlatform",
            "ProvisioningState as PpacProvState",
            "ProvisioningType as PpacProvType",
            @{Name = "FnOEnvType"; Expression = {
                    switch ($_.ProvisioningType) {
                        "OnlineDev" { "UDE" }
                        "Sandbox" { "USE" }
                        Default { "N/A" }
                    }
                }
            },
            *
        }

        if ($UdeOnly) {
            $resCol = $resCol | Where-Object FnOEnvType -eq "UDE"
        }
        elseif ($UseOnly) {
            $resCol = $resCol | Where-Object FnOEnvType -eq "USE"
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-UnifiedEnvironment"
            return
        }

        $resCol
    }
    
    end {
        $ProgressPreference = $currentProgress
    }
}