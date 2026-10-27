<#
.SYNOPSIS
    Compares public declarations without executing PR code.

.DESCRIPTION
    Parses Git objects without importing PR code. Ignores ordinary function
    bodies and formatting. Tracks SDK generation inputs conservatively and
    returns a JSON change report.

.PARAMETER BaseRef
    Baseline Git revision.

.PARAMETER HeadRef
    Proposed Git revision.
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string] $BaseRef,
	[Parameter(Mandatory)]
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

$script:GitBatch = $null
$script:ParsedBlobs = @{}

function Get-ParsedBlob {
	param([string] $ObjectId, [string] $Path, [string] $Revision)
	if ($script:ParsedBlobs.ContainsKey($ObjectId)) { return $script:ParsedBlobs[$ObjectId] }
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
	$parsed = [pscustomobject]@{ SourceText = $sourceText; Ast = $ast }
	$script:ParsedBlobs[$ObjectId] = $parsed
	return $parsed
}

function Get-PublicDeclaration {
	param([string] $Revision)

	$declarations = [ordered]@{}
	$manifestPath = 'd365bap.tools/d365bap.tools.psd1'
	$sdkMapping = 'd365bap.tools/internal/sdk/commands.psd1'
	$sdkGenerator = 'd365bap.tools/internal/scripts/initialize-sdk.ps1'
	$sdkRuntime = 'd365bap.tools/internal/sdk/runtime.ps1'
	$sdkProject = 'library/PowerPlatformSdk/PowerPlatformSdk.csproj'
	$sdkBinary = 'd365bap.tools/bin/PowerPlatformSdk/Microsoft.PowerPlatform.Management.dll'
	$sdkBridge = 'library/PowerPlatformSdk/SdkClient.cs'
	$sdkBridgeBinary = 'd365bap.tools/bin/PowerPlatformSdk/D365Bap.Tools.PowerPlatformSdk.dll'
	$loaderPaths = @('d365bap.tools/d365bap.tools.psm1', 'd365bap.tools/internal/scripts/preimport.ps1', 'd365bap.tools/internal/scripts/postimport.ps1')
	$tree = @(Invoke-GitRead (@('-c', 'core.quotePath=true', 'ls-tree', '-r', $Revision, '--', 'd365bap.tools/functions', $manifestPath, $sdkMapping, $sdkGenerator, $sdkRuntime, 'library/PowerPlatformSdk', 'd365bap.tools/bin/PowerPlatformSdk') + $loaderPaths))
	$objects = [ordered]@{}
	foreach ($entry in $tree) {
		if ($entry -notmatch '^([0-9]{6}) blob ([a-f0-9]+)\t(.+)$') { throw "Invalid Git tree entry in revision $Revision" }
		$mode, $objectId, $path = $Matches[1], $Matches[2], $Matches[3]
		if ($path.StartsWith('"')) { throw "Unsupported quoted Git path in revision $Revision" }
		if ($mode -notin @('100644', '100755')) { throw "Unsupported Git file mode ${mode}: ${Revision}:$path" }
		if ($objects.Contains($path)) { throw "Case-insensitive Git path collision: ${Revision}:$path" }
		$objects[$path] = $objectId
	}
	$paths = @($objects.Keys)
	if ($manifestPath -cnotin $paths) { throw "Missing module manifest: ${Revision}:$manifestPath" }
	$sdkPaths = @($sdkMapping, $sdkGenerator, $sdkRuntime, $sdkProject, $sdkBinary, $sdkBridge, $sdkBridgeBinary)
	if (@($sdkPaths | Where-Object { $_ -cin $paths }).Count -gt 0) {
		foreach ($sdkPath in $sdkPaths) {
			if ($sdkPath -cnotin $paths) { throw "Missing SDK signature input: ${Revision}:$sdkPath" }
		}
	}
	foreach ($path in $paths) {
		if ($path -clike 'library/PowerPlatformSdk/*' -or ($path -clike 'd365bap.tools/bin/PowerPlatformSdk/*' -and $path -match '\.dll$')) {
			$declarations["sdk/$path"] = $objects[$path]
			continue
		}
		if ($path -notmatch '\.(ps1|psd1|psm1)$') { continue }
		$parsed = Get-ParsedBlob -ObjectId $objects[$path] -Path $path -Revision $Revision
		$sourceText = $parsed.SourceText
		$ast = $parsed.Ast

		if ($path -cin $loaderPaths) {
			$declarations["loader/$path"] = ConvertTo-SignatureText $sourceText
			continue
		}
		if ($path -eq $sdkMapping -or $path -eq $sdkGenerator) {
			$declarations["sdk/$path"] = ConvertTo-SignatureText $sourceText
			continue
		}
		if ($path -eq $sdkRuntime) {
			foreach ($functionName in @('Get-BapSdkParameter', 'Import-BapSdk')) {
				$generators = @($ast.EndBlock.Statements | Where-Object {
						$_ -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $functionName
					})
				if ($generators.Count -ne 1) { throw "Expected one SDK parameter generator or importer ($functionName): ${Revision}:$path" }
				$declarations["sdk/$path/$functionName"] = ConvertTo-SignatureText $generators[0].Extent.Text
			}
			continue
		}
		if ($path -eq $manifestPath) {
			$statements = @($ast.EndBlock.Statements)
			if ($statements.Count -ne 1 -or $statements[0] -isnot [System.Management.Automation.Language.PipelineAst] -or
				$statements[0].PipelineElements.Count -ne 1 -or $statements[0].PipelineElements[0] -isnot [System.Management.Automation.Language.CommandExpressionAst] -or
				$statements[0].PipelineElements[0].Expression -isnot [System.Management.Automation.Language.HashtableAst]) {
				throw "Expected a literal module manifest table: ${Revision}:$path"
			}
			foreach ($pair in $statements[0].PipelineElements[0].Expression.KeyValuePairs) {
				$key = $pair.Item1.Extent.Text.Trim("'", '"')
				if ($key -in @('FunctionsToExport', 'CmdletsToExport', 'AliasesToExport', 'VariablesToExport', 'RootModule', 'ModuleToProcess', 'NestedModules', 'RequiredAssemblies', 'ScriptsToProcess')) {
					if ($declarations.Contains("manifest/$key")) { throw "Duplicate manifest export key: ${Revision}:$key" }
					$declarations["manifest/$key"] = ConvertTo-SignatureText $pair.Item2.Extent.Text
				}
			}
			continue
		}

		$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
		if ($functions.Count -eq 0) { throw "No top-level function declaration: $path" }
		$topLevelStatements = @(
			if ($ast.ParamBlock) { $ast.ParamBlock.Extent.Text }
			if ($ast.DynamicParamBlock) { $ast.DynamicParamBlock.Extent.Text }
			if ($ast.BeginBlock) { $ast.BeginBlock.Extent.Text }
			if ($ast.ProcessBlock) { $ast.ProcessBlock.Extent.Text }
			if ($ast.CleanBlock) { $ast.CleanBlock.Extent.Text }
			if ($ast.EndBlock -and -not $ast.EndBlock.Unnamed) { 'end' }
			$ast.EndBlock.Statements | Where-Object { $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst] } | ForEach-Object { $_.Extent.Text }
		)
		if ($topLevelStatements.Count -gt 0) {
			$declarations["$path/<top-level>"] = ConvertTo-SignatureText ($topLevelStatements -join "`n")
		}
		foreach ($function in $functions) {
			$parts = @(
				if ($function.IsFilter) { 'filter' } else { 'function' }
				$function.Name
				foreach ($parameter in $function.Parameters) { $parameter.Extent.Text }
				foreach ($attribute in $function.Body.ParamBlock.Attributes) { $attribute.Extent.Text }
				$function.Body.ParamBlock.Extent.Text
				$function.Body.DynamicParamBlock.Extent.Text
			)
			$declarations["$path/$($function.Name)"] = ConvertTo-SignatureText ($parts -join "`n")
		}
	}
	$declarations
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
		if ($before[$name] -ceq $after[$name]) { continue }
		[ordered]@{ name = $name; before = $before[$name]; after = $after[$name] }
	}
)
ConvertTo-Json -Depth 10 -InputObject @{ changes = $changes }
