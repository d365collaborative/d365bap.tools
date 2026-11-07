<#
    .SYNOPSIS
        Get OData action metadata from a Finance and Operations environment.

    .DESCRIPTION
        Reads the /metadata/PublicEntities endpoint and returns one object per OData action. Each row carries identifiers, binding, return, and parameter details.

    .PARAMETER EnvironmentId
        Environment name, environment GUID (PPAC), or LCS environment ID.

    .PARAMETER Entity
        Filter on entity or collection value.

        Default: *

    .PARAMETER Name
        Filter on action value.

        Default: *

    .PARAMETER AsExcelOutput
        Exports the retrieved metadata to an Excel workbook.

    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity"

        Lists actions bound to one entity.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity "DataManagementEntity" to pick the entity.

    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntities" -Name "*Version*"

        Finds actions with a wildcard filter.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity "DataManagementEntities" to pick the collection.
        It uses -Name "*Version*" to match many actions.

    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Name "*Version*"

        Finds actions across every entity.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Name "*Version*" to match many actions.

    .EXAMPLE
        PS C:\> Get-FscmOdataAction -EnvironmentId "ContosoEnv" -Entity "DataManagementEntity" -AsExcelOutput

        Exports actions for one entity to a workbook.
        It uses -EnvironmentId to select the "ContosoEnv" environment.
        It uses -Entity "DataManagementEntity" to pick the entity.
        It uses -AsExcelOutput to write the rows to a workbook.

    .NOTES
        Author: Mötz Jensen (@Splaxi)
#>
function Get-FscmOdataAction {
	[CmdletBinding()]
	[OutputType('D365Bap.Tools.FscmOdataAction[]')]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $EnvironmentId,

		[SupportsWildcards()]
		[string] $Entity = "*",

		[SupportsWildcards()]
		[string] $Name = "*",

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

		$localUri = '{0}/metadata/PublicEntities' `
			-f $baseUri

		$colMetadataRaw = Invoke-RestMethod -Method Get `
			-Uri $localUri `
			-Headers $hashHeadersFnO |
		Select-Object -ExpandProperty value

		$colEntities = $colMetadataRaw |
		Where-Object {
			($_.Name -like $Entity) `
				-or ($_.Name -eq $Entity) `
				-or ($_.EntitySetName -like $Entity) `
				-or ($_.EntitySetName -eq $Entity)
		}

		$colAction = @(
			foreach ($itemEntity in $colEntities) {
				$entityName = "$($itemEntity.Name)"
				$collectionName = "$($itemEntity.EntitySetName)"

				foreach ($itemAction in ($itemEntity.Actions |
						Where-Object {
							($_.Name -like $Name) `
								-or ($_.Name -eq $Name)
						})) {
					$bindingKind = "$($itemAction.BindingKind)"

					$tmpAllParams = @(
						$itemAction.Parameters |
						Where-Object {
							-Not ($null -eq $_)
						}
					)
					$tmpBindingParam = $tmpAllParams |
					Select-Object -First 1
					$tmpInputParams = @(
						$tmpAllParams |
						Select-Object -Skip 1
					)

					$bindingParamName = "$($tmpBindingParam.Name)"
					$namespace = "Microsoft.Dynamics.DataEntities"

					if ((-not [string]::IsNullOrEmpty($tmpBindingParam.Type.TypeName)) `
							-and ($tmpBindingParam.Type.TypeName.Contains('.'))) {
						$namespace = $tmpBindingParam.Type.TypeName.Substring(0, $tmpBindingParam.Type.TypeName.LastIndexOf('.'))
					}

					$qualifiedAction = "$namespace.$($itemAction.Name)"

					if ($bindingKind -eq "BoundToEntityInstance") {
						$endpoint = "/data/$collectionName(<key>)/$qualifiedAction"
					}
					else {
						$endpoint = "/data/$collectionName/$qualifiedAction"
					}

					$returnType = ""
					$returnIsCollection = $false

					if ((-Not ($null -eq $itemAction.ReturnType)) `
							-and (-not [string]::IsNullOrEmpty($itemAction.ReturnType.TypeName))) {
						$returnType = "$($itemAction.ReturnType.TypeName)"
						$returnIsCollection = [bool]$itemAction.ReturnType.IsCollection
					}

					$tmpParamSummaries = @(
						$tmpInputParams |
						ForEach-Object {
							$paramType = "$($_.Type.TypeName)"

							if ([bool]$_.Type.IsCollection) { $paramType = "Collection($paramType)" }

							"$($_.Name): $paramType"
						} | Sort-Object
					)

					[PSCustomObject][ordered]@{
						EntityName         = $entityName
						CollectionName     = $collectionName
						ActionName         = "$($itemAction.Name)"
						BindingKind        = $bindingKind
						ReturnType         = $returnType
						ReturnIsCollection = $returnIsCollection
						ParameterCount     = $tmpInputParams.Count
						ParametersList     = ($tmpParamSummaries -join ", ")
						BindingParameter   = $bindingParamName
						Endpoint           = $endpoint
						FieldLookup        = "$($itemAction.FieldLookup)"
					}
				}
			}
		)

		$colAction = @(
			$colAction |
			Sort-Object -Property 'EntityName', 'ActionName' |
			Select-PSFObject -TypeName "D365Bap.Tools.FscmOdataAction" `
				-Property *
		)

		if ($AsExcelOutput) {
			$colAction |
			Export-Excel -WorksheetName "Get-FscmOdataAction"
			return
		}

		$colAction
	}

	end {

	}
}
