function Get-Ps1TableFormatType {
	param([string] $TableDirectory)
	if ($null -ne $script:Ps1TableFormatTypes -and $script:Ps1TableFormatTypes.Directory -eq $TableDirectory) {
		$script:Ps1TableFormatTypes.Types; return
	}
	$hashTypes = @{}
	if (Test-Path -LiteralPath $TableDirectory `
			-PathType Container) {
		foreach ($itemFile in Get-ChildItem -LiteralPath $TableDirectory `
				-Filter '*.ps1xml' `
				-File) {
			try {
				[xml] $document = Get-Content -LiteralPath $itemFile.FullName `
					-Raw
			}
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
	if ($Name -notmatch '^(?<Element>.+)\[\]$') { $false; return }
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
	if ($null -eq $type) { $false; return }
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
		if ($name -match '\[\]$|^System\.Collections\.') { $true; return }
	}
	$false
}

function Get-Ps1PipelineStringValue {
	param($Value)
	$expression = $Value
	if ($expression -is [Management.Automation.Language.PipelineAst]) {
		$colElements = @($expression.PipelineElements)
		if ($colElements.Count -ne 1) { $null; return }
		$expression = $colElements[0]
	}
	if ($expression -is [Management.Automation.Language.CommandExpressionAst]) { $expression = $expression.Expression }
	if ($expression -is [Management.Automation.Language.StringConstantExpressionAst]) { $expression; return }
	$null
}

function Get-Ps1StandardOutputDiagnostic {
	param([hashtable] $Analysis)
	$Path = $Analysis.Path

	$scope = $Analysis.Scope
	if (-not (Test-Ps1RuleScope $Analysis 'PublicFunction')) { return }

	$function = @(Get-Ps1AstNode $Analysis FunctionDefinitionAst | Where-Object { $_.Name -eq $scope.FileNameWithoutExtension })[0]
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
	foreach ($itemCommand in @(Get-Ps1AstNode $Analysis CommandAst $function.Body)) {
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
			New-Ps1Diagnostic $Path 'PSUseStandardCollectionOutput' "Add a table format view for '$typeName'. Array output requires a table view; a list view is optional." $argument.Extent
		}
	}

	foreach ($itemHashtable in @(Get-Ps1AstNode $Analysis HashtableAst $function.Body)) {
		foreach ($itemPair in $itemHashtable.KeyValuePairs) {
			if ($itemPair.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if ($itemPair.Item1.Value -ne 'PSTypeName') { continue }
			$value = Get-Ps1PipelineStringValue $itemPair.Item2
			if ($null -eq $value) { continue }
			$typeName = $value.Value
			if ($hashSeen.ContainsKey($typeName)) { continue }
			$hashSeen[$typeName] = $true
			if ($types.ContainsKey($typeName)) { continue }
			New-Ps1Diagnostic $Path 'PSUseStandardCollectionOutput' "Add a table format view for '$typeName'. Array output requires a table view; a list view is optional." $value.Extent
		}
	}

	$hasSwitch = @($function.Body.ParamBlock.Parameters | Where-Object {
			if ($_.Name.VariablePath.UserPath -ne 'AsExcelOutput') { $false; return }
			@($_.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('switch', 'System.Management.Automation.SwitchParameter')
				}).Count -gt 0
		}).Count -gt 0
	if ($hasSwitch) { return }

	New-Ps1Diagnostic $Path 'PSUseStandardCollectionOutput' "Add [switch] `$AsExcelOutput to $($function.Name). Array output must support Excel export." $outputType.Extent
}
