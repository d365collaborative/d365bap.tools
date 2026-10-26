<#
.SYNOPSIS
    Compares public declarations without executing PR code.

.DESCRIPTION
    Reads Git blobs and parses declarations as data. Ignores function bodies,
    comments, whitespace and generated tests. Returns a JSON change report.

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

function Get-PublicDeclaration {
	param([string] $Revision)

	$declarations = [ordered]@{}
	$paths = @(Invoke-GitRead @('ls-tree', '-r', '--name-only', $Revision, '--', 'd365bap.tools/functions', 'd365bap.tools/d365bap.tools.psd1'))
	foreach ($path in $paths) {
		if ($path -notmatch '\.(ps1|psd1)$') { continue }
		$sourceText = ((Invoke-GitRead @('show', "${Revision}:$path")) -join "`n").TrimStart([char]0xFEFF)
		$tokens = $null
		$parseErrors = $null
		$ast = [System.Management.Automation.Language.Parser]::ParseInput($sourceText, [ref]$tokens, [ref]$parseErrors)
		if ($parseErrors.Count -gt 0) { throw "Cannot parse ${Revision}:$path" }

		if ($path -like '*.psd1') {
			$tables = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $false))
			if ($tables.Count -eq 0) { throw "Missing module manifest table: $path" }
			foreach ($pair in $tables[0].KeyValuePairs) {
				$key = $pair.Item1.Extent.Text.Trim("'", '"')
				if ($key -in @('FunctionsToExport', 'CmdletsToExport', 'AliasesToExport')) {
					$declarations["manifest/$key"] = ConvertTo-SignatureText $pair.Item2.Extent.Text
				}
			}
			continue
		}

		$functions = @($ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
		if ($functions.Count -eq 0) { throw "No top-level function declaration: $path" }
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
$before = Get-PublicDeclaration $baseCommit
$after = Get-PublicDeclaration $headCommit
$names = @(@($before.Keys) + @($after.Keys) | Sort-Object -Unique)
$changes = @(
	foreach ($name in $names) {
		if ($before[$name] -ceq $after[$name]) { continue }
		[ordered]@{ name = $name; before = $before[$name]; after = $after[$name] }
	}
)
ConvertTo-Json -Depth 10 -InputObject @{ changes = $changes }
