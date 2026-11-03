
<#
    .SYNOPSIS
        Get UDE environment modules.

    .DESCRIPTION
        Gets the UDE environment modules for a specified environment.

    .PARAMETER EnvironmentId
        The id of the environment that you want to work against

    .PARAMETER LatestOnly
        Instructs the cmdlet to return only the latest module.

        Is based on the modified date.

    .PARAMETER AsExcelOutput
        Instructs the function to export the results to an Excel file.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentModule -EnvironmentId "env-123"

        It retrieves all UDE environment modules for the environment id.
        It uses -EnvironmentId "env-123" to select the environment.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentModule -EnvironmentId "env-123" -LatestOnly

        It retrieves only the latest UDE environment module for the environment.
        It uses -EnvironmentId "env-123" to select the environment.
        It uses -LatestOnly to keep the module with the newest modified date.

    .EXAMPLE
        PS C:\> Get-UnifiedEnvironmentModule -EnvironmentId "env-123" -AsExcelOutput

        It retrieves all UDE environment modules for the environment id.
        It uses -EnvironmentId "env-123" to select the environment.
        It uses -AsExcelOutput to write the results into an Excel file.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-UnifiedEnvironmentModule {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.UdeEnvironmentModule[]')]
	param (

		[Parameter (Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias("PpacEnvId")]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[switch] $LatestOnly,

		[switch] $AsExcelOutput
	)

	begin {
	}

	process {
		$envObj = Get-Environment -Unified `
			-EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$baseUri = $envObj.PpacEnvUri + "/"

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenWebApiValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeaders = @{
			"Authorization"    = "Bearer $($tokenWebApiValue)"
			"Accept"           = "application/json;odata.metadata=minimal"
			"OData-MaxVersion" = "4.0"
			"OData-Version"    = "4.0"
			"Prefer"           = "odata.include-annotations=*"
		}

		$localUri = $baseUri + "api/data/v9.0/msprov_fnomodules"

		$colModules = Invoke-RestMethod -Uri $localUri `
			-Method Get `
			-Headers $hashHeaders |
		Select-Object -ExpandProperty value |
		Sort-Object -Property modifiedon `
			-Descending

		if ($LatestOnly) {
			$colModules = @(
				$colModules |
				Select-Object -First 1
			)
		}

		$colRes = @(
			$colModules |
			Select-PSFObject `
				-TypeName 'D365Bap.Tools.UdeEnvironmentModule' `
				-Property "msprov_name As Name",
			"msprov_fnomoduleid As ModuleId",
			"'_createdby_value@OData.Community.Display.V1.FormattedValue' As CreatedBy",
			"'_modifiedby_value@OData.Community.Display.V1.FormattedValue' As ModifiedBy",
			"'statuscode@OData.Community.Display.V1.FormattedValue' As Status",
			"'statecode@OData.Community.Display.V1.FormattedValue' As State",
			"createdon As Created",
			"modifiedon As Modified",
			"versionnumber As Version",
			* `
				-ExcludeProperty '@odata.etag'
		)

		if ($AsExcelOutput) {
			$colRes |
			Export-Excel -WorksheetName "Get-UnifiedEnvironmentModule"

			return
		}

		$colRes
	}

	end {
	}
}
