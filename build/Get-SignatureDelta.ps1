<#
.SYNOPSIS
    Compares public declarations without executing PR code.

.DESCRIPTION
    Parses Git objects without importing PR code. Ignores bodies and formatting.
    Requires maintainer acceptance only for removed or renamed public parameters,
    or for dropped public cmdlets or exports.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $BaseRef,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $HeadRef
)

$ErrorActionPreference = 'Stop'
$env:GIT_NO_REPLACE_OBJECTS = '1'

function Invoke-GitRead {
	param([string[]] $Arguments)
	$result = & git @Arguments
	if ($LASTEXITCODE -ne 0) { throw "Git read failed: $Arguments" }
	$result
}

function ConvertTo-SignatureText {
	param([string] $SourceText)
	$tokens = $null
	$parseErrors = $null
	$null = [System.Management.Automation.Language.Parser]::ParseInput($SourceText, [ref]$tokens, [ref]$parseErrors)
	(@($tokens | Where-Object { $_.Kind -notin @('Comment', 'NewLine', 'LineContinuation', 'EndOfInput') } | ForEach-Object Text) -join ' ')
}

function Get-DeclarationRecord {
	param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $Fingerprint,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('function', 'export', 'other')]
		[string] $Kind,
		[string[]] $Names = @()
	)
	[pscustomobject]@{
		Fingerprint = $Fingerprint
		Kind        = $Kind
		Names       = @($Names)
	}
}

function Get-FunctionParameterName {
	param($Function)

	$colName = [Collections.Generic.List[string]]::new()
	foreach ($itemParameter in @($Function.Parameters)) {
		$colName.Add($itemParameter.Name.VariablePath.UserPath)
	}
	if ($null -ne $Function.Body.ParamBlock) {
		foreach ($itemParameter in @($Function.Body.ParamBlock.Parameters)) {
			$colName.Add($itemParameter.Name.VariablePath.UserPath)
		}
	}
	@($colName | Select-Object -Unique)
}

function Get-AstStringConstant {
	param($Ast)

	if ($null -eq $Ast) {
		@()
		return
	}
	@($Ast.FindAll({
				param($Node)
				$Node -is [System.Management.Automation.Language.StringConstantExpressionAst]
			}, $true) | ForEach-Object Value)
}

function Test-RemovedName {
	param([string[]] $BeforeNames, [string[]] $AfterNames)

	$colAfter = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	foreach ($itemName in @($AfterNames)) {
		if (-not [string]::IsNullOrEmpty($itemName)) { [void]$colAfter.Add($itemName) }
	}
	foreach ($itemName in @($BeforeNames)) {
		if ([string]::IsNullOrEmpty($itemName)) { continue }
		if (-not $colAfter.Contains($itemName)) {
			$true
			return
		}
	}
	$false
}

function Test-SignatureAcceptanceRequired {
	param(
		$Before,
		$After
	)

	if ($null -eq $Before -and $null -eq $After) {
		$false
		return
	}
	if ($null -eq $After) {
		if ($null -eq $Before) {
			$false
			return
		}
		$Before.Kind -in @('function', 'export')
		return
	}
	if ($null -eq $Before) {
		$false
		return
	}
	if ($Before.Fingerprint -ceq $After.Fingerprint) {
		$false
		return
	}

	if ($Before.Kind -eq 'function' -or $After.Kind -eq 'function') {
		Test-RemovedName -BeforeNames $Before.Names -AfterNames $After.Names
		return
	}
	if ($Before.Kind -eq 'export' -or $After.Kind -eq 'export') {
		Test-RemovedName -BeforeNames $Before.Names -AfterNames $After.Names
		return
	}
	$false
}

$script:GitBatch = $null
$script:ParsedBlobs = @{}

function Get-ParsedBlob {
	param([string] $ObjectId, [string] $Path, [string] $Revision)
	if ($script:ParsedBlobs.ContainsKey($ObjectId)) {
		$script:ParsedBlobs[$ObjectId]
		return
	}
	if (-not $script:GitBatch) {
		$start = [System.Diagnostics.ProcessStartInfo]::new()
		$start.FileName = 'git'
		$start.ArgumentList.Add('cat-file')
		$start.ArgumentList.Add('--batch')
		$start.UseShellExecute = $false
		$start.RedirectStandardInput = $true
		$start.RedirectStandardOutput = $true
		$start.RedirectStandardError = $true
		$script:GitBatch = [System.Diagnostics.Process]::Start($start)
		$script:GitBatchError = $script:GitBatch.StandardError.ReadToEndAsync()
	}
	$script:GitBatch.StandardInput.Write("$ObjectId`n")
	$script:GitBatch.StandardInput.Flush()
	$stream = $script:GitBatch.StandardOutput.BaseStream
	$header = [System.Text.StringBuilder]::new()
	while ($true) {
		$byte = $stream.ReadByte()
		if ($byte -eq -1 -or $header.Length -gt 200) { throw "Invalid Git batch header for ${Revision}:$Path" }
		if ($byte -eq 10) { break }
		$null = $header.Append([char]$byte)
	}
	if ($header.ToString() -notmatch '^([a-f0-9]+) blob ([0-9]+)$' -or $Matches[1] -cne $ObjectId) {
		throw "Invalid Git blob for ${Revision}:$Path"
	}
	$size = [long]$Matches[2]
	if ($size -gt [int]::MaxValue) { throw "Git blob too large: ${Revision}:$Path" }
	$data = [byte[]]::new([int]$size)
	$offset = 0
	while ($offset -lt $data.Length) {
		$count = $stream.Read($data, $offset, $data.Length - $offset)
		if ($count -eq 0) { throw "Incomplete Git blob: ${Revision}:$Path" }
		$offset += $count
	}
	if ($stream.ReadByte() -ne 10) { throw "Invalid Git blob terminator: ${Revision}:$Path" }
	$sourceText = ([System.Text.UTF8Encoding]::new($false, $true).GetString($data)).TrimStart([char]0xFEFF)
	$tokens = $null
	$parseErrors = $null
	$ast = [System.Management.Automation.Language.Parser]::ParseInput($sourceText, [ref]$tokens, [ref]$parseErrors)
	if ($parseErrors.Count -gt 0) { throw "Cannot parse ${Revision}:$Path" }
	$objParsed = [pscustomobject]@{ SourceText = $sourceText; Ast = $ast }
	$script:ParsedBlobs[$ObjectId] = $objParsed
	$objParsed
}

function Get-PublicDeclaration {
	param([string] $Revision)

	$hashDeclarations = [ordered]@{}
	$manifestPath = 'd365bap.tools/d365bap.tools.psd1'
	$sdkMapping = 'd365bap.tools/internal/sdk/commands.psd1'
	$sdkGenerator = 'd365bap.tools/internal/scripts/initialize-sdk.ps1'
	$sdkRuntime = 'd365bap.tools/internal/sdk/runtime.ps1'
	$sdkProject = 'library/PowerPlatformSdk/PowerPlatformSdk.csproj'
	$sdkBinary = 'd365bap.tools/bin/PowerPlatformSdk/Microsoft.PowerPlatform.Management.dll'
	$sdkBridge = 'library/PowerPlatformSdk/SdkClient.cs'
	$sdkBridgeBinary = 'd365bap.tools/bin/PowerPlatformSdk/D365Bap.Tools.PowerPlatformSdk.dll'
	$colLoaderPaths = @('d365bap.tools/d365bap.tools.psm1', 'd365bap.tools/internal/scripts/preimport.ps1', 'd365bap.tools/internal/scripts/postimport.ps1')
	$colExportKey = @('FunctionsToExport', 'CmdletsToExport', 'AliasesToExport', 'VariablesToExport')
	$colTree = @(Invoke-GitRead (@('-c', 'core.quotePath=true', 'ls-tree', '-r', $Revision, '--', 'd365bap.tools/functions', $manifestPath, $sdkMapping, $sdkGenerator, $sdkRuntime, 'library/PowerPlatformSdk', 'd365bap.tools/bin/PowerPlatformSdk') + $colLoaderPaths))
	$hashObjects = [ordered]@{}
	foreach ($itemEntry in $colTree) {
		if ($itemEntry -notmatch '^([0-9]{6}) blob ([a-f0-9]+)\t(.+)$') { throw "Invalid Git tree entry in revision $Revision" }
		$mode, $objectId, $itemPath = $Matches[1], $Matches[2], $Matches[3]
		if ($itemPath.StartsWith('"')) { throw "Unsupported quoted Git path in revision $Revision" }
		if ($mode -notin @('100644', '100755')) { throw "Unsupported Git file mode ${mode}: ${Revision}:$itemPath" }
		if ($hashObjects.Contains($itemPath)) { throw "Case-insensitive Git path collision: ${Revision}:$itemPath" }
		$hashObjects[$itemPath] = $objectId
	}
	$colPaths = @($hashObjects.Keys)
	if ($manifestPath -cnotin $colPaths) { throw "Missing module manifest: ${Revision}:$manifestPath" }
	$colSdkPaths = @($sdkMapping, $sdkGenerator, $sdkRuntime, $sdkProject, $sdkBinary, $sdkBridge, $sdkBridgeBinary)
	if (@($colSdkPaths | Where-Object { $_ -cin $colPaths }).Count -gt 0) {
		foreach ($itemSdkPath in $colSdkPaths) {
			if ($itemSdkPath -cnotin $colPaths) { throw "Missing SDK signature input: ${Revision}:$itemSdkPath" }
		}
	}
	foreach ($itemPath in $colPaths) {
		if ($itemPath -clike 'library/PowerPlatformSdk/*' -or ($itemPath -clike 'd365bap.tools/bin/PowerPlatformSdk/*' -and $itemPath -match '\.dll$')) {
			$hashDeclarations["sdk/$itemPath"] = Get-DeclarationRecord -Fingerprint $hashObjects[$itemPath] -Kind other
			continue
		}
		if ($itemPath -notmatch '\.(ps1|psd1|psm1)$') { continue }
		$parsed = Get-ParsedBlob -ObjectId $hashObjects[$itemPath] -Path $itemPath -Revision $Revision
		$sourceText = $parsed.SourceText
		$ast = $parsed.Ast

		if ($itemPath -cin $colLoaderPaths) {
			$hashDeclarations["loader/$itemPath"] = Get-DeclarationRecord -Fingerprint (ConvertTo-SignatureText $sourceText) -Kind other
			continue
		}
		if ($itemPath -eq $sdkMapping -or $itemPath -eq $sdkGenerator) {
			$hashDeclarations["sdk/$itemPath"] = Get-DeclarationRecord -Fingerprint (ConvertTo-SignatureText $sourceText) -Kind other
			continue
		}
		if ($itemPath -eq $sdkRuntime) {
			foreach ($itemFunctionName in @('Get-BapSdkParameter', 'Import-BapSdk')) {
				$tmpGenerators = @($ast.EndBlock.Statements | Where-Object {
						$_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $itemFunctionName
					})
				if ($tmpGenerators.Count -ne 1) { throw "Expected one SDK parameter generator or importer ($itemFunctionName): ${Revision}:$itemPath" }
				$hashDeclarations["sdk/$itemPath/$itemFunctionName"] = Get-DeclarationRecord -Fingerprint (ConvertTo-SignatureText $tmpGenerators[0].Extent.Text) -Kind other
			}
			continue
		}
		if ($itemPath -eq $manifestPath) {
			$tmpStatements = @($ast.EndBlock.Statements)
			if ($tmpStatements.Count -ne 1 -or $tmpStatements[0] -isnot [System.Management.Automation.Language.PipelineAst] -or
				$tmpStatements[0].PipelineElements.Count -ne 1 -or $tmpStatements[0].PipelineElements[0] -isnot [System.Management.Automation.Language.CommandExpressionAst] -or
				$tmpStatements[0].PipelineElements[0].Expression -isnot [System.Management.Automation.Language.HashtableAst]) {
				throw "Expected a literal module manifest table: ${Revision}:$itemPath"
			}
			foreach ($itemPair in $tmpStatements[0].PipelineElements[0].Expression.KeyValuePairs) {
				$key = $itemPair.Item1.Extent.Text.Trim("'", '"')
				if ($key -in @('FunctionsToExport', 'CmdletsToExport', 'AliasesToExport', 'VariablesToExport', 'RootModule', 'ModuleToProcess', 'NestedModules', 'RequiredAssemblies', 'ScriptsToProcess')) {
					if ($hashDeclarations.Contains("manifest/$key")) { throw "Duplicate manifest export key: ${Revision}:$key" }
					$fingerprint = ConvertTo-SignatureText $itemPair.Item2.Extent.Text
					if ($key -in $colExportKey) {
						$hashDeclarations["manifest/$key"] = Get-DeclarationRecord -Fingerprint $fingerprint -Kind export -Names (Get-AstStringConstant $itemPair.Item2)
					}
					else {
						$hashDeclarations["manifest/$key"] = Get-DeclarationRecord -Fingerprint $fingerprint -Kind other
					}
				}
			}
			continue
		}

		$tmpFunctions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
		if ($tmpFunctions.Count -eq 0) { throw "No top-level function declaration: $itemPath" }
		$tmpTopLevelStatements = @(
			if ($ast.ParamBlock) { $ast.ParamBlock.Extent.Text }
			if ($ast.DynamicParamBlock) { $ast.DynamicParamBlock.Extent.Text }
			if ($ast.BeginBlock) { $ast.BeginBlock.Extent.Text }
			if ($ast.ProcessBlock) { $ast.ProcessBlock.Extent.Text }
			if ($ast.CleanBlock) { $ast.CleanBlock.Extent.Text }
			if ($ast.EndBlock -and -not $ast.EndBlock.Unnamed) { 'end' }
			$ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] } | ForEach-Object { $_.Extent.Text }
		)
		if ($tmpTopLevelStatements.Count -gt 0) {
			$hashDeclarations["$itemPath/<top-level>"] = Get-DeclarationRecord -Fingerprint (ConvertTo-SignatureText ($tmpTopLevelStatements -join "`n")) -Kind other
		}
		foreach ($itemFunction in $tmpFunctions) {
			$tmpParts = @(
				if ($itemFunction.IsFilter) { 'filter' } else { 'function' }
				$itemFunction.Name
				foreach ($itemParameter in $itemFunction.Parameters) { $itemParameter.Extent.Text }
				foreach ($itemAttribute in $itemFunction.Body.ParamBlock.Attributes) { $itemAttribute.Extent.Text }
				$itemFunction.Body.ParamBlock.Extent.Text
				$itemFunction.Body.DynamicParamBlock.Extent.Text
			)
			$hashDeclarations["$itemPath/$($itemFunction.Name)"] = Get-DeclarationRecord `
				-Fingerprint (ConvertTo-SignatureText ($tmpParts -join "`n")) `
				-Kind function `
				-Names (Get-FunctionParameterName $itemFunction)
		}
	}
	$hashDeclarations
}

$baseCommit = Invoke-GitRead @('rev-parse', '--verify', "$BaseRef^{commit}")
$headCommit = Invoke-GitRead @('rev-parse', '--verify', "$HeadRef^{commit}")
try {
	$before = Get-PublicDeclaration $baseCommit
	$after = Get-PublicDeclaration $headCommit
}
finally {
	if ($script:GitBatch) {
		$script:GitBatch.StandardInput.Close()
		if (-not $script:GitBatch.WaitForExit(5000)) {
			$script:GitBatch.Kill()
			$script:GitBatch.Dispose()
			throw 'Git batch process did not terminate.'
		}
		$exitCode = $script:GitBatch.ExitCode
		$null = $script:GitBatchError.GetAwaiter().GetResult()
		$script:GitBatch.Dispose()
		if ($exitCode -ne 0) { throw 'Git batch process failed.' }
	}
}
$names = @(@($before.Keys) + @($after.Keys) | Sort-Object -Unique)
$changes = @(
	foreach ($name in $names) {
		$itemBefore = $before[$name]
		$itemAfter = $after[$name]
		if (-not (Test-SignatureAcceptanceRequired -Before $itemBefore -After $itemAfter)) { continue }
		[ordered]@{
			name   = $name
			before = if ($null -eq $itemBefore) { $null } else { $itemBefore.Fingerprint }
			after  = if ($null -eq $itemAfter) { $null } else { $itemAfter.Fingerprint }
		}
	}
)
ConvertTo-Json -Depth 10 -InputObject @{ changes = $changes }
