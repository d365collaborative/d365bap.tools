<#
    .SYNOPSIS
        Remove UDE environment packages.

    .DESCRIPTION
        Removes UDE environment packages (msprov_fnopackage records) for a specified environment.

        Packages are matched by package id and name. Nothing is removed unless the -Force switch is supplied.
        Without -Force the cmdlet lists the packages that would be removed.

    .PARAMETER EnvironmentId
        The id of the environment that you want to work against

    .PARAMETER PackageId
        The id of the package that you want to remove.

        Supports wildcard characters for flexible matching against the package id.

    .PARAMETER Name
        The name of the package that you want to remove.

        Supports wildcard characters for flexible matching against the package name.

    .PARAMETER Force
        Instructs the function to proceed with removing the packages.

        Nothing happens unless this parameter is supplied.

    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironmentPackage -EnvironmentId "env-123" -PackageId "a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6"

        This will show the package that would be removed for the specified environment id.
        It will NOT remove the package yet, allowing you to review it before deciding to remove it.

    .EXAMPLE
        PS C:\> Remove-UnifiedEnvironmentPackage -EnvironmentId "env-123" -PackageId "a1b2c3d4-e5f6-47a8-b9c0-d1e2f3a4b5c6" -Force

        This will remove the specified package for the specified environment id without further confirmation.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentPackage -EnvironmentId "env-123" | Remove-UnifiedEnvironmentPackage -Force

        This will remove all packages returned for the specified environment id without further confirmation.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Remove-UnifiedEnvironmentPackage {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("PpacEnvId")]
        [string] $EnvironmentId,

        [Parameter (ValueFromPipelineByPropertyName = $true)]
        [string] $PackageId = "*",

        [Parameter (ValueFromPipelineByPropertyName = $true)]
        [string] $Name = "*",

        [switch] $Force
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

        $localUri = $baseUri + "api/data/v9.0/msprov_fnopackages"

        $colPackages = Invoke-RestMethod -Uri $localUri `
            -Method Get `
            -Headers $headers | `
            Select-Object -ExpandProperty value | `
            Sort-Object -Property modifiedon -Descending

        $resCol = @(
            $colPackages | Select-PSFObject -TypeName 'D365Bap.Tools.UdeEnvironmentPackage' `
                -Property "msprov_name As Name",
            "msprov_fnopackageid As PackageId",
            "'_createdby_value@OData.Community.Display.V1.FormattedValue' As CreatedBy",
            "'_modifiedby_value@OData.Community.Display.V1.FormattedValue' As ModifiedBy",
            "'msprov_packagetype@OData.Community.Display.V1.FormattedValue' As PackageType",
            "'msprov_buildtype@OData.Community.Display.V1.FormattedValue' As BuildType",
            "'msprov_dbsyncoptions@OData.Community.Display.V1.FormattedValue' As DbSync",
            "'statuscode@OData.Community.Display.V1.FormattedValue' As Status",
            "'statecode@OData.Community.Display.V1.FormattedValue' As State",
            "createdon As Created",
            "modifiedon As Modified",
            "versionnumber As Version",
            * `
                -ExcludeProperty '@odata.etag'
        )

        $colFiltered = @($resCol | Where-Object { $_.PackageId -like $PackageId -and $_.Name -like $Name })

        if ($colFiltered.Count -lt 1) {
            $messageString = "No packages found for environment <c='em'>$EnvironmentId</c> matching PackageId <c='em'>$PackageId</c> and Name <c='em'>$Name</c>. Please verify the filters and try again, or list available packages using <c='em'>Get-UnifiedEnvironmentPackage</c>."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because no packages were found based on the supplied filters." `
                -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        if (-not $Force) {
            Write-PSFMessage -Level Important -Message "The following packages would be removed:"
            $colFiltered | ForEach-Object { Write-PSFMessage -Level Important -Message " - <c='em'>$($_.Name)</c> ($($_.PackageId))" }

            $messageString = "This will remove the listed packages. If you are sure, please re-run the command with the <c='em'>-Force</c> parameter."

            Write-PSFMessage -Level Important -Message $messageString
            Stop-PSFFunction -Message "Stopping because Force parameter wasn't supplied." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        [System.Collections.Generic.List[System.Object]] $arrFailed = @()

        foreach ($packageObj in $colFiltered) {
            $deleteUri = $baseUri + "api/data/v9.0/msprov_fnopackages($($packageObj.PackageId))"

            $deleteParams = @{
                Method             = 'Delete'
                Uri                = $deleteUri
                Headers            = $headers
                SkipHttpErrorCheck = $true
                StatusCodeVariable = 'statusDelete'
            }

            Invoke-RestMethod @deleteParams > $null 4>$null

            if (-not ($statusDelete -like "2**")) {
                Write-PSFMessage -Level Important -Message "Failed to remove package <c='em'>$($packageObj.Name)</c> ($($packageObj.PackageId)). HTTP status code: $statusDelete."
                $arrFailed.Add($packageObj)
            }
            else {
                Write-PSFMessage -Level Verbose -Message "Removed package '$($packageObj.Name)' ($($packageObj.PackageId))."
            }
        }

        if ($arrFailed.Count -gt 0) {
            $messageString = "The following packages <c='em'>failed to be removed</c>:"

            Write-PSFMessage -Level Important -Message $messageString
            $arrFailed.ToArray()

            if ($arrFailed.Count -eq $colFiltered.Count) {
                Stop-PSFFunction -Message "Stopping because all package removals failed." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }
        }
    }

    end {
    }
}
