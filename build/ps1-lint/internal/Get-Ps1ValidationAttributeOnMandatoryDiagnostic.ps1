function Get-Ps1ValidationNotNullOrEmptyAttribute {
	param($Parameter)

	@($Parameter.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and (
				$_.TypeName.GetReflectionAttributeType() -eq [System.Management.Automation.ValidateNotNullOrEmptyAttribute] -or
				$_.TypeName.FullName -in @('ValidateNotNullOrEmpty', 'ValidateNotNullOrEmptyAttribute', 'System.Management.Automation.ValidateNotNullOrEmptyAttribute')
			)
		})[0]
}

function Get-Ps1ValidationAttributeOnMandatoryDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	if (-not (Test-Ps1RuleScope $Analysis 'FunctionFile')) { return }

	foreach ($itemFunction in @(Get-Ps1AstNode $Analysis FunctionDefinitionAst)) {
		if ($null -eq $itemFunction.Body.ParamBlock) { continue }

		foreach ($itemParameter in $itemFunction.Body.ParamBlock.Parameters) {
			$attribute = Get-Ps1ValidationNotNullOrEmptyAttribute -Parameter $itemParameter
			if ($null -eq $attribute) { continue }
			if (Test-Ps1MandatoryParameter -Parameter $itemParameter) { continue }
			if ($null -ne $itemParameter.DefaultValue) { continue }

			$name = $itemParameter.Name.VariablePath.UserPath
			New-Ps1Diagnostic $Path 'PSUseValidationAttributeOnMandatory' "Parameter -$name declares [ValidateNotNullOrEmpty()] but is not mandatory and has no default. Make it mandatory, give it a default, or state the contract with [ValidateScript()]." $attribute.Extent
		}
	}
}
