[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $BaseSha,
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[string] $HeadSha,
	[string] $RepositoryPath = (Join-Path $PSScriptRoot '..'),
	[string] $OutputPath
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ps1-lint/internal/Get-Ps1OutputTypeDiagnostic.ps1')

function Invoke-ScopeGitBytes {
	param([string] $Repository, [string[]] $Arguments)

	$start = [System.Diagnostics.ProcessStartInfo]::new()
	$start.FileName = 'git'
	$start.WorkingDirectory = $Repository
	$start.UseShellExecute = $false
	$start.RedirectStandardOutput = $true
	$start.RedirectStandardError = $true
	foreach ($itemArgument in $Arguments) { $null = $start.ArgumentList.Add($itemArgument) }
	$process = [System.Diagnostics.Process]::Start($start)
	try {
		$errorTask = $process.StandardError.ReadToEndAsync()
		$bytes = [System.IO.MemoryStream]::new()
		try {
			$process.StandardOutput.BaseStream.CopyTo($bytes)
			$process.WaitForExit()
			$stderr = $errorTask.GetAwaiter().GetResult()
			if ($process.ExitCode -ne 0) { throw "git failed ($($process.ExitCode)): $stderr" }
			, $bytes.ToArray()
		}
		finally { $bytes.Dispose() }
	}
	finally { $process.Dispose() }
}

function Invoke-ScopeGitText {
	param([string] $Repository, [string[]] $Arguments)

	$raw = Invoke-ScopeGitBytes -Repository $Repository -Arguments $Arguments
	[Text.Encoding]::UTF8.GetString($raw)
}

function Get-ScopeChangedFile {
	param([string] $Repository, [string] $Base, [string] $Head)

	foreach ($itemSha in @($Base, $Head)) {
		if ($itemSha -notmatch '^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$') { throw "Invalid commit object ID: $itemSha" }
	}
	$mergeBase = (Invoke-ScopeGitText -Repository $Repository -Arguments @('merge-base', $Base, $Head)).Trim()
	if ($mergeBase -notmatch '^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$') { throw 'Could not determine a unique merge base.' }

	$raw = Invoke-ScopeGitBytes -Repository $Repository -Arguments @('diff', '--name-status', '-z', '--find-renames', $mergeBase, $Head, '--')
	$records = [Text.Encoding]::UTF8.GetString($raw).Split([char]0)
	if ($records[-1] -ne '') { throw 'Git returned an unterminated diff record.' }

	for ($index = 0; $index -lt $records.Length - 1; ) {
		$status = $records[$index++]
		if ($status -notmatch '^[A-Z][0-9]*$' -or $index -ge $records.Length - 1) { throw 'Malformed git diff output.' }
		$path = $records[$index++]
		$oldPath = $null
		if ($status -match '^[RC]') {
			if ($index -ge $records.Length - 1) { throw 'Malformed rename/copy record.' }
			$oldPath = $path
			$path = $records[$index++]
		}
		[pscustomobject]@{ Status = $status; Path = $path; OldPath = $oldPath; MergeBase = $mergeBase }
	}
}

function Get-ScopeTextAtRevision {
	param([string] $Repository, [string] $Revision, [string] $Path)

	try {
		Invoke-ScopeGitText -Repository $Repository -Arguments @('show', "${Revision}:$Path")
	}
	catch {
		$null
	}
}

function Get-ScopeAst {
	param([string] $Text)

	if ([string]::IsNullOrEmpty($Text)) { return }
	$tokens = $null
	$errors = $null
	[Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
}

function Get-ScopeFileFunction {
	param($Ast, [string] $Path)

	if ($null -eq $Ast) { return }
	$name = [IO.Path]::GetFileNameWithoutExtension($Path)
	$colFunctions = @($Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true))
	@($colFunctions | Where-Object Name -eq $name)[0]
}

function Get-ScopeDeclaredType {
	param([string] $Text, [string] $Path)

	$ast = Get-ScopeAst -Text $Text
	$function = Get-ScopeFileFunction -Ast $ast -Path $Path
	if ($null -eq $function) { return }

	$declaration = Get-Ps1OutputTypeDeclared -Function $function
	@($declaration.Types)
}

function Get-ScopeFormatTypeName {
	param([string] $Path, [string] $Text)

	try {
		[xml] $document = $Text
	}
	catch {
		throw "Invalid format XML '$Path': $($_.Exception.Message)"
	}

	foreach ($itemType in @($document.Configuration.ViewDefinitions.View.ViewSelectedBy.TypeName)) {
		if ($null -ne $itemType -and "$itemType" -ne '') { "$itemType" }
	}
}

function Test-ScopeGeneratedTestFile {
	param([string] $Path)

	$Path -match '^d365bap\.tools/tests/functions/[^/]+\.Tests\.ps1$'
}

function Get-ScopePowerShellFile {
	param([string] $Repository, [string] $RelativeDirectory)

	$root = if ([string]::IsNullOrEmpty($RelativeDirectory)) { $Repository } else { Join-Path $Repository $RelativeDirectory }
	if (-not (Test-Path -LiteralPath $root -PathType Container)) { return }

	$prefixLength = $Repository.TrimEnd([IO.Path]::DirectorySeparatorChar).Length + 1
	foreach ($itemFile in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1') {
		$relative = $itemFile.FullName.Substring($prefixLength) -replace '\\', '/'
		if (Test-ScopeGeneratedTestFile $relative) { continue }
		$relative
	}
}

function Get-ScopeModuleFunctionIndex {
	param([string] $Repository)

	foreach ($itemRelativeRoot in @('d365bap.tools/functions', 'd365bap.tools/internal/functions', 'd365bap.tools/internal/scripts')) {
		foreach ($itemRelativePath in @(Get-ScopePowerShellFile -Repository $Repository -RelativeDirectory $itemRelativeRoot)) {
			$itemPath = Join-Path $Repository $itemRelativePath
			$text = Get-Content -LiteralPath $itemPath -Raw
			$ast = Get-ScopeAst -Text $text
			$function = Get-ScopeFileFunction -Ast $ast -Path $itemRelativePath
			if ($null -eq $function) { continue }

			[pscustomobject]@{
				Path    = $itemRelativePath
				Types   = @((Get-Ps1OutputTypeDeclared -Function $function).Types)
				Emitted = @(Get-Ps1OutputTypePSFName -Function $function)
			}
		}
	}
}

function Get-ScopeCallerIndex {
	param([string] $Repository)

	$hashCallers = @{}
	foreach ($itemRelativeRoot in @('d365bap.tools', 'build')) {
		foreach ($itemRelativePath in @(Get-ScopePowerShellFile -Repository $Repository -RelativeDirectory $itemRelativeRoot)) {
			$text = Get-Content -LiteralPath (Join-Path $Repository $itemRelativePath) -Raw
			$ast = Get-ScopeAst -Text $text
			if ($null -eq $ast) { continue }

			foreach ($itemCommand in $ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
				$name = $itemCommand.GetCommandName()
				if ($null -eq $name) { continue }
				$name = ($name -split '\\')[-1]
				if (-not $hashCallers.ContainsKey($name)) {
					$hashCallers[$name] = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
				}
				$null = $hashCallers[$name].Add($itemRelativePath)
			}
		}
	}
	$hashCallers
}

function Add-ScopeFile {
	param(
		[Collections.Generic.HashSet[string]] $Files,
		[Collections.Generic.HashSet[string]] $Dependencies,
		[Collections.Generic.List[object]] $Reasons,
		[string] $Path,
		[string] $Kind,
		[string] $Reason,
		[bool] $Dependency = $true
	)

	if ([string]::IsNullOrWhiteSpace($Path)) { return }
	$normalized = $Path -replace '\\', '/'
	if (Test-ScopeGeneratedTestFile $normalized) { return }
	$null = $Files.Add($normalized)
	if ($Dependency) { $null = $Dependencies.Add($normalized) }
	$Reasons.Add([pscustomobject]@{ Path = $normalized; Kind = $Kind; Reason = $Reason })
}

$repository = (Resolve-Path -LiteralPath $RepositoryPath).Path
$colChanged = @(Get-ScopeChangedFile -Repository $repository -Base $BaseSha -Head $HeadSha)
$mergeBase = if ($colChanged.Count -gt 0) { $colChanged[0].MergeBase } else {
	(Invoke-ScopeGitText -Repository $repository -Arguments @('merge-base', $BaseSha, $HeadSha)).Trim()
}

$colFiles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$colDependencies = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$colReasons = [Collections.Generic.List[object]]::new()
$colInvalidFormats = [Collections.Generic.List[string]]::new()
$hasFullScan = $false
$hashFunctionIndex = $null
$hashCallerIndex = $null

foreach ($itemChange in $colChanged) {
	$path = $itemChange.Path -replace '\\', '/'
	if ($path -match '\.ps1$' -and $itemChange.Status -notmatch '^D') {
		Add-ScopeFile -Files $colFiles -Dependencies $colDependencies -Reasons $colReasons -Path $path -Kind 'Changed' -Reason 'Changed PowerShell file' -Dependency $false
	}

	if ([IO.Path]::GetFileName($path) -ieq 'ps1-lint.json') {
		$directory = Split-Path $path -Parent
		foreach ($itemPath in @(Get-ScopePowerShellFile -Repository $repository -RelativeDirectory $directory)) {
			Add-ScopeFile -Files $colFiles -Dependencies $colDependencies -Reasons $colReasons -Path $itemPath -Kind 'AliasConfiguration' -Reason "ps1-lint.json changed in $directory"
		}
	}

	if ($path -match '^d365bap\.tools/xml/.+\.ps1xml$') {
		try {
			$text = Get-Content -LiteralPath (Join-Path $repository $path) -Raw
			$colTypes = @(Get-ScopeFormatTypeName -Path $path -Text $text)
		}
		catch {
			$colInvalidFormats.Add("$path`: $($_.Exception.Message)")
			continue
		}

		if ($colTypes.Count -eq 0) { continue }
		if ($null -eq $hashFunctionIndex) { $hashFunctionIndex = Get-ScopeModuleFunctionIndex -Repository $repository }
		foreach ($itemFunction in $hashFunctionIndex) {
			$matched = @($colTypes | Where-Object {
					$itemType = $_
					@($itemFunction.Types | Where-Object { $_ -ieq $itemType -or $_ -ieq "$itemType[]" -or $_.TrimEnd('[]') -ieq $itemType.TrimEnd('[]') }).Count -gt 0 -or
					@($itemFunction.Emitted | Where-Object { $_ -ieq $itemType }).Count -gt 0
				}).Count -gt 0
			if (-not $matched) { continue }
			Add-ScopeFile -Files $colFiles -Dependencies $colDependencies -Reasons $colReasons -Path $itemFunction.Path -Kind 'FormatView' -Reason "Format view changed for $($colTypes -join ', ')"
		}
	}

	if ($path -match '^build/ps1-lint/|^prek\.toml$') {
		$hasFullScan = $true
		foreach ($itemPath in @(Get-ScopePowerShellFile -Repository $repository -RelativeDirectory 'd365bap.tools')) {
			Add-ScopeFile -Files $colFiles -Dependencies $colDependencies -Reasons $colReasons -Path $itemPath -Kind 'RuleChange' -Reason 'Lint rule implementation or settings changed'
		}
		foreach ($itemPath in @(Get-ScopePowerShellFile -Repository $repository -RelativeDirectory 'build')) {
			Add-ScopeFile -Files $colFiles -Dependencies $colDependencies -Reasons $colReasons -Path $itemPath -Kind 'RuleChange' -Reason 'Lint rule implementation or settings changed'
		}
	}

	if ($itemChange.Status -notmatch '^D' -and $path -match '^d365bap\.tools/(functions|internal/functions)/[^/]+\.ps1$') {
		$baseText = Get-ScopeTextAtRevision -Repository $repository -Revision $mergeBase -Path $itemChange.OldPath ?? $path
		$headText = Get-Content -LiteralPath (Join-Path $repository $path) -Raw
		$baseTypes = @(Get-ScopeDeclaredType -Text $baseText -Path $path | Sort-Object -Unique)
		$headTypes = @(Get-ScopeDeclaredType -Text $headText -Path $path | Sort-Object -Unique)
		if (($baseTypes -join '|') -cne ($headTypes -join '|')) {
			$functionName = [IO.Path]::GetFileNameWithoutExtension($path)
			if ($null -eq $hashCallerIndex) { $hashCallerIndex = Get-ScopeCallerIndex -Repository $repository }
			if ($hashCallerIndex.ContainsKey($functionName)) {
				foreach ($itemCaller in $hashCallerIndex[$functionName]) {
					Add-ScopeFile -Files $colFiles -Dependencies $colDependencies -Reasons $colReasons -Path $itemCaller -Kind 'OutputType' -Reason "OutputType of $functionName changed"
				}
			}
		}
	}
}

$scope = [pscustomobject]@{
	BaseSha            = $BaseSha
	HeadSha            = $HeadSha
	MergeBase          = $mergeBase
	Files              = @($colFiles | Sort-Object)
	DependencyFiles    = @($colDependencies | Sort-Object)
	Reasons            = @($colReasons | Sort-Object Path, Kind, Reason)
	InvalidFormatFiles = @($colInvalidFormats)
	FullScan           = $hasFullScan
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
	$scope | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}

$scope
