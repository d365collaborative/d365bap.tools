. "$PSScriptRoot/Get-Ps1OutputModel.ps1"

function Get-Ps1OutputTypeDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'OutputTypeFile')) { return }
	foreach ($itemFunction in @(Get-Ps1OutputTopLevelFunction -Analysis $Analysis)) {
		Get-Ps1OutputTypeFunctionDiagnostic $Analysis $itemFunction
	}
}

function Get-Ps1OutputTypeFunctionDiagnostic {
	param($Analysis, $itemFunction)
	$Path = $Analysis.Path

	$model = Get-Ps1OutputFunctionModel -Function $itemFunction `
		-Analysis $Analysis
	$declaration = $model.Declaration
	$colTypes = @($declaration.Types)

	if (-not $declaration.HasAttribute) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "Function $($itemFunction.Name) must declare [OutputType()]. Use [OutputType([void])] when it emits no output." $itemFunction.Extent
		return
	}

	if ($colTypes.Count -eq 0) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "OutputType on $($itemFunction.Name) must declare at least one type. Use [OutputType([void])] when it emits no output." $declaration.Attributes[0].Extent
		return
	}

	$hasVoid = @($colTypes | Where-Object { $_ -match '^(system\.)?void$' }).Count -gt 0
	if ($hasVoid -and $colTypes.Count -gt 1) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "OutputType on $($itemFunction.Name) mixes [void] with other types. Declare either [void] or the emitted types." $declaration.Attributes[0].Extent
		return
	}

	$colPSFNames = @($model.CustomTypes | ForEach-Object { $_.Name })
	if ($colPSFNames.Count -gt 0) {
		foreach ($itemPSFName in $colPSFNames) {
			$matching = @($colTypes | Where-Object {
					$_ -ieq $itemPSFName -or $_ -ieq "$itemPSFName[]"
				}).Count -gt 0

			if (-not $matching) {
				New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "Function $($itemFunction.Name) emits '$itemPSFName' but OutputType does not declare '$itemPSFName' or '$itemPSFName[]'." $itemFunction.Extent
			}
		}

		return
	}

	$hasSpecificType = @($colTypes | Where-Object { $_ -notmatch '^(system\.)?(object|psobject)(\[\])?$' }).Count -gt 0
	if (-not $hasSpecificType) {
		New-Ps1Diagnostic $Path 'PSUseDeclaredOutputType' "OutputType on $($itemFunction.Name) only declares System.Object. Use the actual type, [PSCustomObject] for anonymous objects, or [void] when it emits no output." $declaration.Attributes[0].Extent
	}
}
