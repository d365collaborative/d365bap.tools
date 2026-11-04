<#
    .SYNOPSIS
        Get REST service metadata from a Finance and Operations environment.

    .DESCRIPTION
        Reads the /api/services endpoint and returns one object per node at the
        requested depth. Higher-level identifiers stay populated, and each row
        carries an error message when a request fails.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Name
        Filter on service group, service, operation, or parameter name.

        Default: *

    .PARAMETER TraverseTo
        Controls how deep the service hierarchy is expanded.

        Default: ServiceGroup

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv"

        Lists every service group in the environment.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses the default -TraverseTo ServiceGroup.

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Service

        Lists every service within each service group.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -TraverseTo Service to expand one level deeper.

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Operation -Name "*Sales*"

        Finds operations whose group, service, or operation name contains "Sales".
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -TraverseTo Operation to return one row per operation.
        It uses -Name "*Sales*" to filter the hierarchy by wildcard.

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Detail -Name "SalesOrderService"

        Returns one row per operation parameter for matching names.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -TraverseTo Detail to return the parameter level.
        It uses -Name "SalesOrderService" to filter the hierarchy.

    .EXAMPLE
        PS C:\> Get-FscmRestService -EnvironmentId "ContosoEnv" -TraverseTo Detail -AsExcelOutput

        Exports full parameter details to an Excel workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -TraverseTo Detail to return the parameter level.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmRestService {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmRestService[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $Name = "*",

		[string] $TraverseTo = "ServiceGroup",

		[switch] $AsExcelOutput
	)

	begin {
		$envObj = Get-Environment -EnvironmentId $EnvironmentId |
		Select-Object -First 1

		$baseUri = $envObj.FnOEnvUri -replace '.com/', '.com'

		$objSecureToken = Get-BapAccessToken -ResourceUrl $baseUri
		$tokenFnoOdataValue = ConvertFrom-SecureString -AsPlainText `
			-SecureString $objSecureToken

		$hashHeadersFnO = @{
			"Authorization" = "Bearer $($tokenFnoOdataValue)"
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		$localUri = '{0}/api/services' `
			-f $baseUri

		$resStatusCode = $null
		$responseRoot = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO `
			-StatusCodeVariable 'resStatusCode' `
			-SkipHttpErrorCheck

		if ($resStatusCode -ne 200) {
			[PSCustomObject][ordered]@{
				PSTypeName    = "D365Bap.Tools.FscmRestService"
				ServiceGroup  = $null
				Service       = $null
				Operation     = $null
				Parameter     = $null
				ParameterType = $null
				ReturnType    = $null
				ErrorMessage  = $responseRoot |
				ConvertTo-Json -Depth 10
			}
			return
		}

		$resColRaw = $responseRoot |
		Select-Object -ExpandProperty ServiceGroups |
		Where-Object {
			$_.Name -like $Name
		} | ForEach-Object -Parallel {
			$serviceGroup = $_
			$baseUri = $using:baseUri
			$hashHeadersFnO = $using:hashHeadersFnO
			$TraverseTo = $using:TraverseTo

			$tmpObjHash = [Ordered]@{
				ServiceGroup = $serviceGroup.Name
				Endpoint     = ''
				ErrorMessage = ''
			}

			if ($TraverseTo -eq "ServiceGroup") {
				[PSCustomObject]$tmpObjHash
				return
			}

			$localUri = '{0}/api/services/{1}' `
				-f $baseUri,
			$serviceGroup.Name
			$resStatusCode = $null
			$responseGroup = Invoke-RestMethod -Method Get `
				-Uri $localUri `
				-Headers $hashHeadersFnO `
				-StatusCodeVariable 'resStatusCode' `
				-SkipHttpErrorCheck

			if ($resStatusCode -ne 200) {
				$tmpObjHash.ErrorMessage = $responseGroup |
				ConvertTo-Json -Depth 10

				[PSCustomObject]$tmpObjHash
				return
			}

			foreach ($itemService in ($responseGroup |
					Select-Object -ExpandProperty Services)) {
				$tmpObjHash.Service = $itemService.Name

				if ($TraverseTo -eq "Service") {
					[PSCustomObject]$tmpObjHash
					continue
				}

				$localUri = '{0}/api/services/{1}/{2}' `
					-f $baseUri,
				$serviceGroup.Name,
				$itemService.Name
				$resStatusCode = $null
				$responseService = Invoke-RestMethod -Method Get `
					-Uri $localUri `
					-Headers $hashHeadersFnO `
					-StatusCodeVariable 'resStatusCode' `
					-SkipHttpErrorCheck

				if ($resStatusCode -ne 200) {
					$tmpObjHash.ErrorMessage = $responseService |
					ConvertTo-Json -Depth 10

					[PSCustomObject]$tmpObjHash
					continue
				}

				foreach ($itemOperation in ($responseService |
						Select-Object -ExpandProperty Operations)) {
					$tmpObjHash.Operation = $itemOperation.Name
					$tmpObjHash.Endpoint = "$($serviceGroup.Name)/$($itemService.Name)/$($itemOperation.Name)"
					$tmpObjHash.ReturnType = $itemOperation.ReturnType

					if ($TraverseTo -eq "Operation") {
						[PSCustomObject]$tmpObjHash
						continue
					}

					$localUri = '{0}/api/services/{1}/{2}/{3}' `
						-f $baseUri,
					$serviceGroup.Name,
					$itemService.Name,
					$itemOperation.Name
					$resStatusCode = $null
					$responseOperation = Invoke-RestMethod -Method Get `
						-Uri $localUri `
						-Headers $hashHeadersFnO `
						-StatusCodeVariable 'resStatusCode' `
						-SkipHttpErrorCheck

					if ($resStatusCode -ne 200) {
						$tmpObjHash.ErrorMessage = $responseOperation |
						ConvertTo-Json -Depth 10

						[PSCustomObject]$tmpObjHash
						continue
					}

					foreach ($itemParameter in $responseOperation.Parameters) {
						$tmpObjHash.Parameter = $itemParameter.Name
						$tmpObjHash.ParameterType = $itemParameter.Type

						[PSCustomObject]$tmpObjHash
						continue
					}
				}
			}
		} -ThrottleLimit 10

		$resCol = $resColRaw |
		Select-PSFObject -TypeName "D365Bap.Tools.FscmRestService" `
			-Property `
			ServiceGroup,
		Service,
		Operation,
		Endpoint,
		ReturnType,
		Parameter,
		ParameterType,
		ErrorMessage |
		Sort-Object -Property 'ServiceGroup', 'Service', 'Operation', 'Parameter'

		if ($AsExcelOutput) {
			$resCol |
			Export-Excel -WorksheetName 'Get-FscmRestService'
			return
		}

		$resCol
	}

	end {

	}
}
