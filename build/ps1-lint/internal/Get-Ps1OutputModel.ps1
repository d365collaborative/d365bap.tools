function Test-Ps1OutputOwnedNode {
	param($Node, $Function)
	$parent = $Node.Parent
	while ($null -ne $parent -and $parent -isnot [Management.Automation.Language.FunctionDefinitionAst]) { $parent = $parent.Parent }
	$parent -eq $Function
}

function Get-Ps1OutputTopLevelFunction {
	param([hashtable] $Analysis)

	@(Get-Ps1AstNode $Analysis FunctionDefinitionAst | Where-Object {
			$_.Parent -isnot [Management.Automation.Language.FunctionMemberAst] -and
			(Test-Ps1OutputOwnedNode -Node $_ `
				-Function $null)
		})
}

function Get-Ps1OutputCommandName {
	param($Command)

	$name = $Command.GetCommandName()
	if ($null -eq $name) { $null; return }
	($name -split '\\')[-1]
}

function Get-Ps1OutputTypeDeclared {
	param($Function)

	$paramBlock = $Function.Body.ParamBlock
	if ($null -eq $paramBlock) {
		[pscustomobject]@{ HasAttribute = $false; Types = @(); Attributes = @(); CollectionAttribute = $null }; return
	}

	$colAttributes = @($paramBlock.Attributes | Where-Object {
			$_ -is [Management.Automation.Language.AttributeAst] -and
			$_.TypeName.Name -match '^OutputType(Attribute)?$'
		})
	$colTypes = [System.Collections.Generic.List[string]]::new()
	$collectionAttribute = $null
	foreach ($itemAttribute in $colAttributes) {
		foreach ($itemArgument in @($itemAttribute.PositionalArguments)) {
			$typeName = $null
			if ($itemArgument -is [Management.Automation.Language.StringConstantExpressionAst]) { $typeName = $itemArgument.Value }
			elseif ($itemArgument -is [Management.Automation.Language.TypeExpressionAst]) { $typeName = $itemArgument.TypeName.FullName }
			elseif ($itemArgument -is [Management.Automation.Language.TypeConstraintAst]) { $typeName = $itemArgument.TypeName.FullName }

			if (-not [string]::IsNullOrWhiteSpace($typeName)) {
				$typeName = $typeName.Trim("'", '"')
				$colTypes.Add($typeName)
				if ($null -eq $collectionAttribute -and (Test-Ps1OutputCollectionName $typeName)) { $collectionAttribute = $itemAttribute }
			}
		}
	}

	[pscustomobject]@{
		HasAttribute        = $colAttributes.Count -gt 0
		Types               = $colTypes.ToArray()
		Attributes          = $colAttributes
		CollectionAttribute = $collectionAttribute
	}
}

function Get-Ps1OutputCustomType {
	param($Function)

	$hashSeen = @{}
	$colResult = [System.Collections.Generic.List[object]]::new()

	foreach ($itemCommand in $Function.Body.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.CommandAst] -and
				(Get-Ps1OutputCommandName $Node) -eq 'Select-PSFObject' -and
				(Test-Ps1OutputOwnedNode -Node $Node `
					-Function $Function)
			}, $true)) {
		$tmpElements = @($itemCommand.CommandElements)
		for ($index = 0; $index -lt $tmpElements.Count; $index++) {
			$tmpElement = $tmpElements[$index]
			if ($tmpElement -isnot [Management.Automation.Language.CommandParameterAst]) { continue }
			if ($tmpElement.ParameterName -notin @('TypeName', 'Type')) { continue }

			$tmpArgument = $null
			if ($null -ne $tmpElement.Argument) { $tmpArgument = $tmpElement.Argument }
			elseif ($index + 1 -lt $tmpElements.Count) { $tmpArgument = $tmpElements[$index + 1] }

			if ($tmpArgument -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if ($hashSeen.ContainsKey($tmpArgument.Value)) { continue }
			$hashSeen[$tmpArgument.Value] = $true
			$colResult.Add([pscustomobject]@{ Name = $tmpArgument.Value; Extent = $tmpArgument.Extent })
		}
	}

	foreach ($itemHashtable in $Function.Body.FindAll({
				param($Node)
				$Node -is [Management.Automation.Language.HashtableAst] -and
				(Test-Ps1OutputOwnedNode -Node $Node `
					-Function $Function)
			}, $true)) {
		foreach ($itemPair in $itemHashtable.KeyValuePairs) {
			if ($itemPair.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if ($itemPair.Item1.Value -ne 'PSTypeName') { continue }

			$tmpValue = $itemPair.Item2
			if ($tmpValue -is [Management.Automation.Language.PipelineAst] -and $tmpValue.PipelineElements.Count -eq 1) { $tmpValue = $tmpValue.PipelineElements[0] }
			if ($tmpValue -is [Management.Automation.Language.CommandExpressionAst]) { $tmpValue = $tmpValue.Expression }
			if ($tmpValue -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
			if ($hashSeen.ContainsKey($tmpValue.Value)) { continue }
			$hashSeen[$tmpValue.Value] = $true
			$colResult.Add([pscustomobject]@{ Name = $tmpValue.Value; Extent = $tmpValue.Extent })
		}
	}

	$colResult
}

function Get-Ps1OutputTypePSFName {
	param($Function)

	$colNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	foreach ($itemType in @(Get-Ps1OutputCustomType -Function $Function)) {
		$colNames.Add($itemType.Name) > $null
	}

	$colNames
}

function Test-Ps1OutputScalarArray {
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

function Test-Ps1OutputCollectionName {
	param([string] $Name)

	if (Test-Ps1OutputScalarArray $Name) { $false; return }
	$Name -match '\[\]$|^System\.Collections\.'
}

function Test-Ps1OutputExcelSwitch {
	param($Function)

	$paramBlock = $Function.Body.ParamBlock
	if ($null -eq $paramBlock) { $false; return }

	@($paramBlock.Parameters | Where-Object {
			if ($_.Name.VariablePath.UserPath -ne 'AsExcelOutput') { $false; return }
			@($_.Attributes | Where-Object {
					$_ -is [Management.Automation.Language.TypeConstraintAst] -and
					$_.TypeName.FullName -in @('switch', 'System.Management.Automation.SwitchParameter')
				}).Count -gt 0
		}).Count -gt 0
}

function Get-Ps1OutputFunctionModel {
	param($Function, [hashtable] $Analysis)
	if ($null -ne $Analysis) {
		if (-not $Analysis.ContainsKey('OutputFunctionModels')) { $Analysis.OutputFunctionModels = @{} }
		if ($Analysis.OutputFunctionModels.ContainsKey($Function)) { $Analysis.OutputFunctionModels[$Function]; return }
	}
	$declaration = Get-Ps1OutputTypeDeclared -Function $Function
	$objModel = [pscustomobject]@{
		Declaration    = $declaration
		CustomTypes    = @(Get-Ps1OutputCustomType -Function $Function)
		HasExcelSwitch = Test-Ps1OutputExcelSwitch -Function $Function
		IsCollection   = $null -ne $declaration.CollectionAttribute
	}
	if ($null -ne $Analysis) { $Analysis.OutputFunctionModels[$Function] = $objModel }
	$objModel
}
