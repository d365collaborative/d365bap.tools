[CmdletBinding()]
param(
	[Parameter(Mandatory)] [string] $ModuleRoot,
	[Parameter(Mandatory)] [string[]] $CommandPath,
	[Parameter(Mandatory)] [string] $ExceptionsFile
)
$ErrorActionPreference = 'Stop'
Import-Module PSModuleDevelopment -ErrorAction Stop
$exceptions = & $ExceptionsFile
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('selected-strings-' + [guid]::NewGuid().ToString('N'))
try {
	$null = New-Item -ItemType Directory -Path $temporaryRoot -Force
	$sourceRoot = Join-Path $temporaryRoot 'functions'
	$null = New-Item -ItemType Directory -Path $sourceRoot
	$index = 0
	foreach ($path in $CommandPath) {
		if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Selected string source missing: $path" }
		Copy-Item -LiteralPath $path -Destination (Join-Path $sourceRoot ("{0:D6}.ps1" -f $index))
		$index++
	}
	if ($index -eq 0) { throw 'No source files selected for string validation.' }
	$languages = @(Get-ChildItem -LiteralPath $ModuleRoot -Directory | Where-Object Name -match '^\w\w-\w\w$')
	if ($languages.Count -eq 0) { throw 'No module language directories found.' }
	foreach ($language in $languages) {
		$files = @(Get-ChildItem -LiteralPath $language.FullName -File -Filter '*.psd1')
		if ($files.Count -eq 0) { throw "No language files found in $($language.FullName)." }
		$destination = Join-Path $temporaryRoot $language.Name
		$null = New-Item -ItemType Directory -Path $destination
		foreach ($file in $files) { Copy-Item -LiteralPath $file.FullName -Destination $destination }
	}
	$findings = @(Export-PSMDString -ModuleRoot $temporaryRoot -ErrorAction Stop)
	$missing = @($findings | Where-Object { -not $_.Surplus -and $_.String -ne 'key' -and $exceptions.NoTextNeeded -notcontains $_.String -and [string]::IsNullOrEmpty($_.Text) })
	if ($missing.Count -gt 0) {
		$missing | Format-Table Language, String, Text -AutoSize | Out-Host
		throw 'Selected source files reference localization strings without text.'
	}
	Write-Host "Selected localization strings validated for $index source file(s)."
}
finally {
	if (Test-Path -LiteralPath $temporaryRoot) {
		$resolved = (Resolve-Path -LiteralPath $temporaryRoot).Path
		$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Temporary string fixture escaped the temporary directory.' }
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
