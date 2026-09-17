
<#
    .SYNOPSIS
        Get UDE environment models.
        
    .DESCRIPTION
        Gets the currently installed models for a specified environment.
        
        Works against any unified environment (UDE, USE and others).
        
        Installed state is taken from the latest completed msprov_fnopackage
        per model. A latest completed Delete package means the model is not
        installed. The msprov_fnomodule table is only used to enrich the
        output when a matching row exists.
        
    .PARAMETER EnvironmentId
        The id of the environment that you want to work against
        
    .PARAMETER Name
        The name of the model that you are looking for.
        
        Supports wildcard patterns.
        
    .PARAMETER LatestOnly
        Instructs the cmdlet to return only the latest model.
        
        Is based on the modified date.
        
    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.
        
    .EXAMPLE
        PS C:\> Get-UdeEnvironmentModel -EnvironmentId "env-123"
        
        This will retrieve all models for the specified environment id.
        
    .EXAMPLE
        PS C:\> Get-UdeEnvironmentModel -EnvironmentId "env-123" -Name "B"
        
        This will retrieve the model named B for the specified environment id.
        
    .EXAMPLE
        PS C:\> Get-UdeEnvironmentModel -EnvironmentId "env-123" -Name "B*" -LatestOnly
        
        This will retrieve only the latest model matching B* for the specified environment id.
        It is based on the modified date.
        
    .EXAMPLE
        PS C:\> Get-UdeEnvironmentModel -EnvironmentId "env-123" -AsExcelOutput
        
        This will retrieve all models for the specified environment id.
        Will output all details into an Excel file, that will auto open on your machine.
        
    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeEnvironmentModel {
    [CmdletBinding()]
    [OutputType('System.Object[]')]
    param (

        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [string] $Name = "*",

        [switch] $LatestOnly,

        [switch] $AsExcelOutput
    )

    begin {
    }

    process {
        if (Test-PSFFunctionInterrupt) { return }

        $envObj = Get-UnifiedEnvironment -EnvironmentId $EnvironmentId -SkipVersionDetails | Select-Object -First 1

        if ($null -eq $envObj) {
            $messageString = "Could not find environment with Id <c='em'>$EnvironmentId</c>. Please verify the Id and try again, or list available environments using <c='em'>Get-UnifiedEnvironment</c>. Consider using wildcards if needed."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because environment was NOT found based on the id." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        $baseUri = $envObj.PpacEnvUri + "/" #! Very important to have the trailing slash

        $secureToken = (Get-AzAccessToken -ResourceUrl $baseUri -AsSecureString).Token
        $tokenWebApiValue = ConvertFrom-SecureString -AsPlainText -SecureString $secureToken

        $headers = @{
            "Authorization"    = "Bearer $($tokenWebApiValue)"
            "Accept"           = "application/json;odata.metadata=minimal" # minimal || full
            "OData-MaxVersion" = "4.0"
            "OData-Version"    = "4.0"
            "Prefer"           = "odata.include-annotations=*"
        }

        $colPackages = Invoke-RestMethod -Uri ($baseUri + "api/data/v9.0/msprov_fnopackages") `
            -Method Get `
            -Headers $headers | `
            Select-Object -ExpandProperty value | `
            Sort-Object -Property modifiedon -Descending

        $hashLatestCompletedByModel = @{}

        foreach ($packageObj in $colPackages) {
            if ("$($packageObj.statuscode)" -ne "4") { continue }

            $modelName = Get-UdePackageModelName -PackageName $packageObj.msprov_name

            if ([System.String]::IsNullOrWhiteSpace($modelName)) { continue }
            if ($hashLatestCompletedByModel.ContainsKey($modelName)) { continue }

            $hashLatestCompletedByModel[$modelName] = $packageObj
        }

        $colInstalledNames = @(
            $hashLatestCompletedByModel.Keys | Where-Object {
                "$($hashLatestCompletedByModel[$_].msprov_buildtype)" -ne "2" -and $_ -like $Name
            }
        )

        $colModules = Invoke-RestMethod -Uri ($baseUri + "api/data/v9.0/msprov_fnomodules") `
            -Method Get `
            -Headers $headers | `
            Select-Object -ExpandProperty value

        $hashModuleByName = @{}

        foreach ($moduleObj in $colModules) {
            $hashModuleByName["$($moduleObj.msprov_name)"] = $moduleObj
        }

        $buildTypeNames = @{
            "0" = "Full"
            "1" = "Incremental"
            "2" = "Delete"
            "3" = "DBSync"
        }

        $colInstalled = @(
            foreach ($modelName in $colInstalledNames) {
                $packageObj = $hashLatestCompletedByModel[$modelName]
                $moduleObj = $hashModuleByName[$modelName]

                $createdOn = $null
                $modifiedOn = $packageObj.modifiedon
                $createdBy = $null
                $modifiedBy = $null
                $status = $null
                $state = $null
                $moduleId = $null
                $version = $null

                if ($null -ne $moduleObj) {
                    $createdOn = $moduleObj.createdon
                    $createdBy = $moduleObj.'_createdby_value@OData.Community.Display.V1.FormattedValue'
                    $modifiedBy = $moduleObj.'_modifiedby_value@OData.Community.Display.V1.FormattedValue'
                    $status = $moduleObj.'statuscode@OData.Community.Display.V1.FormattedValue'
                    $state = $moduleObj.'statecode@OData.Community.Display.V1.FormattedValue'
                    $moduleId = $moduleObj.msprov_fnomoduleid
                    $version = $moduleObj.versionnumber
                }

                if ($null -eq $createdOn) { $createdOn = $packageObj.createdon }
                if ([System.String]::IsNullOrWhiteSpace($createdBy)) { $createdBy = $packageObj.'_createdby_value@OData.Community.Display.V1.FormattedValue' }
                if ([System.String]::IsNullOrWhiteSpace($modifiedBy)) { $modifiedBy = $packageObj.'_modifiedby_value@OData.Community.Display.V1.FormattedValue' }
                if ([System.String]::IsNullOrWhiteSpace($status)) { $status = $packageObj.'statuscode@OData.Community.Display.V1.FormattedValue' }
                if ([System.String]::IsNullOrWhiteSpace($state)) { $state = $packageObj.'statecode@OData.Community.Display.V1.FormattedValue' }

                $buildType = $buildTypeNames["$($packageObj.msprov_buildtype)"]
                if ([System.String]::IsNullOrWhiteSpace($buildType)) { $buildType = "$($packageObj.msprov_buildtype)" }

                $createdUtc = $null
                $modifiedUtc = $null

                if ($null -ne $createdOn) { $createdUtc = ([datetime]$createdOn).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") }
                if ($null -ne $modifiedOn) { $modifiedUtc = ([datetime]$modifiedOn).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss") }

                [PsCustomObject][ordered]@{
                    Name         = $modelName
                    ModuleId     = $moduleId
                    PackageId    = $packageObj.msprov_fnopackageid
                    PackageName  = $packageObj.msprov_name
                    BuildType    = $buildType
                    CreatedBy    = $createdBy
                    ModifiedBy   = $modifiedBy
                    Status       = $status
                    State        = $state
                    Created      = $createdOn
                    CreatedUtc   = $createdUtc
                    Modified     = $modifiedOn
                    ModifiedUtc  = $modifiedUtc
                    Version      = $version
                    PSTypeName   = 'D365Bap.Tools.UdeEnvironmentModel'
                }
            }
        )

        $colInstalled = @($colInstalled | Sort-Object -Property Modified -Descending)

        if ($LatestOnly) {
            $colInstalled = $colInstalled | Select-Object -First 1
        }

        $resCol = @(
            $colInstalled | Select-PSFObject -TypeName 'D365Bap.Tools.UdeEnvironmentModel' -Property *
        )

        if ($AsExcelOutput) {
            $resCol | Export-Excel -WorksheetName "Get-UdeEnvironmentModel"
            return
        }

        $resCol
    }

    end {
    }
}