function Get-Ps1TableFormatType {
	param([string] $TableDirectory)
	if ($null -ne $script:Ps1TableFormatTypes -and $script:Ps1TableFormatTypes.Directory -eq $TableDirectory) {
		return $script:Ps1TableFormatTypes.Types
	}
	$types = @{}
	if (Test-Path -LiteralPath $TableDirectory -PathType Container) {
		foreach ($file in Get-ChildItem -LiteralPath $TableDirectory -Filter '*.ps1xml' -File) {
			try { [xml] $document = Get-Content -LiteralPath $file.FullName -Raw }
			catch { continue }
			foreach ($typeName in @($document.Configuration.ViewDefinitions.View.ViewSelectedBy.TypeName)) {
				if ($null -ne $typeName -and $typeName -ne '') { $types[[string]$typeName] = $true }
			}
		}
	}
	$script:Ps1TableFormatTypes = @{ Directory = $TableDirectory; Types = $types }
	$types
}

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

function Get-Ps1PipelineStringValue {
	param($Value)
	$expression = $Value
	if ($expression -is [Management.Automation.Language.PipelineAst]) {
		$elements = @($expression.PipelineElements)
		if ($elements.Count -ne 1) { return $null }
		$expression = $elements[0]
	}
	if ($expression -is [Management.Automation.Language.CommandExpressionAst]) { $expression = $expression.Expression }
	if ($expression -is [Management.Automation.Language.StringConstantExpressionAst]) { return $expression }
	$null
}

function Write-Ps1CollectionOutputDiagnostic {
	param([string] $Path, [string] $Message, $Extent)
	[pscustomobject]@{
		RuleName   = 'PSUseStandardCollectionOutput'
		Severity   = 'Error'
		ScriptName = [IO.Path]::GetFileName($Path)
		Line       = $Extent.StartLineNumber
		Column     = $Extent.StartColumnNumber
		Message    = $Message
	}
}

function Get-Ps1StandardOutputDiagnostic {
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

	$moduleRoot = Split-Path (Split-Path $Path -Parent) -Parent
	$types = Get-Ps1TableFormatType (Join-Path $moduleRoot 'xml/formats/table')

	$seen = @{}
	foreach ($command in $function.Body.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
		if ($command.GetCommandName() -notmatch '(?:^|\\)Select-PSFObject$') { continue }
		$elements = @($command.CommandElements)
		for ($index = 0; $index -lt $elements.Count; $index++) {
			$element = $elements[$index]
			if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if ($element.ParameterName -notin @('TypeName', 'Type')) { continue }
			if ($index + 1 -ge $elements.Count) { continue }
			$argument = $elements[$index + 1]
			if ($argument -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			$typeName = $argument.Value
			if ($seen.ContainsKey($typeName)) { continue }
			$seen[$typeName] = $true
			if ($types.ContainsKey($typeName)) { continue }
			Write-Ps1CollectionOutputDiagnostic $Path "Add a table format view for '$typeName'. Array output requires a table view; a list view is optional." $argument.Extent
		}
	}

	foreach ($hashtable in $function.Body.FindAll({ param($node) $node -is [Management.Automation.Language.HashtableAst] }, $true)) {
		foreach ($pair in $hashtable.KeyValuePairs) {
			if ($pair.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if ($pair.Item1.Value -ne 'PSTypeName') { continue }
			$value = Get-Ps1PipelineStringValue $pair.Item2
			if ($null -eq $value) { continue }
			$typeName = $value.Value
			if ($seen.ContainsKey($typeName)) { continue }
			$seen[$typeName] = $true
			if ($types.ContainsKey($typeName)) { continue }
			Write-Ps1CollectionOutputDiagnostic $Path "Add a table format view for '$typeName'. Array output requires a table view; a list view is optional." $value.Extent
		}
	}

	$hasSwitch = @($function.Body.ParamBlock.Parameters | Where-Object {
			if ($_.Name.VariablePath.UserPath -ne 'AsExcelOutput') { return $false }
			@($_.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('switch', 'System.Management.Automation.SwitchParameter')
				}).Count -gt 0
		}).Count -gt 0
	if ($hasSwitch) { return }

	Write-Ps1CollectionOutputDiagnostic $Path "Add [switch] `$AsExcelOutput to $($function.Name). Array output must support Excel export." $outputType.Extent
}
