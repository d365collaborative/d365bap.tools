
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
            -FnOEnabled

        $searchById = Test-Guid -InputObject $EnvironmentId

        $currentProgress = $ProgressPreference
        $ProgressPreference = "SilentlyContinue"
    }
    
    process {
        $resCol = @(
            foreach ($envObj in $($colEnv | Where-Object FinOpsMetadataEnvType -eq "Internal")) {
                if ($searchById) {
                    # Name is the GUID
                    if (-not ($envObj.PpacEnvId -like $EnvironmentId)) { continue }
                }
                else {
                    # DisplayName is the name
                    if (-not ($envObj.PpacEnvName -like $EnvironmentId)) { continue }
                }

                if ($SkipVersionDetails) {
                    $envObj

                    continue
                }

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
                    $messageString = "Could not obtain the <c='em'>Ppac Provision</c> details for <c='em'>$($envObj.PpacEnvName)</c>. It could be due to insufficient permissions or the environment not being fully provisioned. Please try to access the environment details from PowerPlatform Admin Center."
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
        )

        if ($UdeOnly) {
            $resCol = $resCol | Where-Object FnOEnvType -eq "UDE"
        }
        elseif ($UseOnly) {
            $resCol = $resCol | Where-Object FnOEnvType -eq "USE"
        }

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-UdeEnvironment"
            return
        }

        $resCol
    }
    
    end {
        $ProgressPreference = $currentProgress
    }
}