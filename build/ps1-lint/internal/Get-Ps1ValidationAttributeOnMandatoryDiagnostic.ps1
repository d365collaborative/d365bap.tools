function Get-Ps1ValidationNotNullOrEmptyAttribute {
	param($Parameter)

	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [System.Management.Automation.ValidateNotNullOrEmptyAttribute] -or
				$_.TypeName.FullName -in @('ValidateNotNullOrEmpty', 'ValidateNotNullOrEmptyAttribute', 'System.Management.Automation.ValidateNotNullOrEmptyAttribute')
			)
		})[0]
}

function New-Ps1ValidationAttributeOnMandatoryDiagnostic {
	param([string] $Path, [string] $Message, $Extent)

	[pscustomobject]@{
		RuleName   = 'PSUseValidationAttributeOnMandatory'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1ValidationAttributeOnMandatoryDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/(functions|internal/functions)/[^/]+\.ps1$') { return }
	if ([IO.Path]::GetFileName($Path) -like '*Tests.ps1') { return }

	foreach ($itemFunction in $Analysis.Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
		if ($null -eq $itemFunction.Body.ParamBlock) { continue }

		foreach ($itemParameter in $itemFunction.Body.ParamBlock.Parameters) {
			$attribute = Get-Ps1ValidationNotNullOrEmptyAttribute -Parameter $itemParameter
			if ($null -eq $attribute) { continue }
			if (Test-Ps1MandatoryParameter -Parameter $itemParameter) { continue }
			if ($null -ne $itemParameter.DefaultValue) { continue }

			$name = $itemParameter.Name.VariablePath.UserPath
			New-Ps1ValidationAttributeOnMandatoryDiagnostic -Path $Path -Extent $attribute.Extent -Message "Parameter -$name declares [ValidateNotNullOrEmpty()] but is not mandatory and has no default. Make it mandatory, give it a default, or state the contract with [ValidateScript()]."
		}
	}
}
