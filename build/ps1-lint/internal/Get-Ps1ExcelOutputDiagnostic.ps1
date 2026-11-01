function Test-Ps1ScalarArray {
	param([string] $Name)
	if ($Name -notmatch '^(?<Element>.+)\[\]$') { return $false }
	$element = $Matches['Element']
	$accelerator = @{
		string         = [string]
		bool           = [bool]
		byte           = [byte]
		sbyte          = [sbyte]
		short          = [int16]
		ushort         = [uint16]
		int            = [int]
		uint           = [uint32]
		long           = [long]
		ulong          = [uint64]
		float          = [single]
		double         = [double]
		decimal        = [decimal]
		char           = [char]
		datetime       = [datetime]
		datetimeoffset = [datetimeoffset]
		timespan       = [timespan]
		guid           = [guid]
	}
	$type = [type]::GetType($element)
	if ($null -eq $type) { $type = $accelerator[$element.ToLowerInvariant()] }
	if ($null -eq $type) { return $false }
	$type.IsValueType -or $type -eq [string]
}

function Test-Ps1CollectionOutput {
	param($Attribute)
	foreach ($argument in $Attribute.PositionalArguments) {
		$name = if ($argument -is [Management.Automation.Language.TypeExpressionAst]) {
			$argument.TypeName.FullName
		}
		elseif ($argument -is [Management.Automation.Language.StringConstantExpressionAst]) {
			$argument.Value
		}
		else { '' }
		if (Test-Ps1ScalarArray $name) { continue }
		if ($name -match '\[\]$|^System\.Collections\.') { return $true }
	}
	$false
}

function Get-Ps1ExcelOutputDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$normalized = $Path -replace '\\', '/'
	if ($normalized -notmatch '/d365bap\.tools/functions/[^/]+\.ps1$') { return }

	$function = @($Analysis.Ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true) | Where-Object { $_.Name -eq [IO.Path]::GetFileNameWithoutExtension($Path) })[0]
	if ($null -eq $function -or $null -eq $function.Body.ParamBlock) { return }

	$outputType = @($function.Body.ParamBlock.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and
			$_.TypeName.FullName -match '^OutputType(Attribute)?$' -and
			(Test-Ps1CollectionOutput $_)
		})[0]
	if ($null -eq $outputType) { return }

	$hasSwitch = @($function.Body.ParamBlock.Parameters | Where-Object {
			if ($_.Name.VariablePath.UserPath -ne 'AsExcelOutput') { return $false }
			@($_.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('switch', 'System.Management.Automation.SwitchParameter')
				}).Count -gt 0
		}).Count -gt 0
	if ($hasSwitch) { return }

	[pscustomobject]@{
		RuleName   = 'PSUseAsExcelOutput'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $outputType.Extent.StartLineNumber
		Column     = $outputType.Extent.StartColumnNumber
		Message    = "Add [switch] `$AsExcelOutput to $($function.Name). Array output must support Excel export."
	}
}
