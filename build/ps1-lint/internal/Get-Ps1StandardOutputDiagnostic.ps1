function Get-Ps1TableFormatType {
	param([string] $TableDirectory)
	if ($null -ne $script:Ps1TableFormatTypes -and $script:Ps1TableFormatTypes.Directory -eq $TableDirectory) {
		return $script:Ps1TableFormatTypes.Types
	}
	$hashTypes = @{}
	if (Test-Path -LiteralPath $TableDirectory -PathType Container) {
		foreach ($itemFile in Get-ChildItem -LiteralPath $TableDirectory -Filter '*.ps1xml' -File) {
			try { [xml] $document = Get-Content -LiteralPath $itemFile.FullName -Raw }
			catch { continue }
			foreach ($itemTypeName in @($document.Configuration.ViewDefinitions.View.ViewSelectedBy.TypeName)) {
				if ($null -ne $itemTypeName -and $itemTypeName -ne '') { $hashTypes[[string]$itemTypeName] = $true }
			}
		}
	}
	$script:Ps1TableFormatTypes = @{ Directory = $TableDirectory; Types = $hashTypes }
	$hashTypes
}

function Test-Ps1ScalarArray {
	param([string] $Name)
	if ($Name -notmatch '^(?<Element>.+)\[\]$') { return $false }
	$element = $Matches['Element']
	$hashAccelerator = @{
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
	if ($null -eq $type) { $type = $hashAccelerator[$element.ToLowerInvariant()] }
	if ($null -eq $type) { return $false }
	$type.IsValueType -or $type -eq [string]
}

function Test-Ps1CollectionOutput {
	param($Attribute)
	foreach ($itemArgument in $Attribute.PositionalArguments) {
		$name = if ($itemArgument -is [Management.Automation.Language.TypeExpressionAst]) {
			$itemArgument.TypeName.FullName
		}
		elseif ($itemArgument -is [Management.Automation.Language.StringConstantExpressionAst]) {
			$itemArgument.Value
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
		$colElements = @($expression.PipelineElements)
		if ($colElements.Count -ne 1) { return $null }
		$expression = $colElements[0]
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

	$hashSeen = @{}
	foreach ($itemCommand in $function.Body.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true)) {
		if ($itemCommand.GetCommandName() -notmatch '(?:^|\\)Select-PSFObject$') { continue }
		$tmpElements = @($itemCommand.CommandElements)
		for ($index = 0; $index -lt $tmpElements.Count; $index++) {
			$element = $tmpElements[$index]
			if ($element -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if ($element.ParameterName -notin @('TypeName', 'Type')) { continue }
			if ($index + 1 -ge $tmpElements.Count) { continue }
			$argument = $tmpElements[$index + 1]
			if ($argument -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			$typeName = $argument.Value
			if ($hashSeen.ContainsKey($typeName)) { continue }
			$hashSeen[$typeName] = $true
			if ($types.ContainsKey($typeName)) { continue }
			Write-Ps1CollectionOutputDiagnostic $Path "Add a table format view for '$typeName'. Array output requires a table view; a list view is optional." $argument.Extent
		}
	}

	foreach ($itemHashtable in $function.Body.FindAll({ param($node) $node -is [Management.Automation.Language.HashtableAst] }, $true)) {
		foreach ($itemPair in $itemHashtable.KeyValuePairs) {
			if ($itemPair.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if ($itemPair.Item1.Value -ne 'PSTypeName') { continue }
			$value = Get-Ps1PipelineStringValue $itemPair.Item2
			if ($null -eq $value) { continue }
			$typeName = $value.Value
			if ($hashSeen.ContainsKey($typeName)) { continue }
			$hashSeen[$typeName] = $true
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
