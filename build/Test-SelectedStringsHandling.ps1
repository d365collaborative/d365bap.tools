[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('strings-validation-test-' + [guid]::NewGuid().ToString('N'))
$source = Join-Path $fixture 'selected.ps1'
$language = Join-Path $fixture 'en-us'
$exceptions = Join-Path $fixture 'exceptions.ps1'
function Test-Check([string] $Content, [bool] $ExpectedSuccess, [string] $Label) {
	Set-Content -LiteralPath $source -Value $Content -Encoding utf8BOM
	$succeeded = $true
	try { & (Join-Path $PSScriptRoot 'Test-SelectedStrings.ps1') -ModuleRoot $fixture -CommandPath @($source) -ExceptionsFile $exceptions }
	catch { $succeeded = $false; Write-Host "Caught: $($_.Exception.Message)" }
	if ($succeeded -ne $ExpectedSuccess) { throw "Unexpected result for $Label" }
	Write-Host "PASS: $Label"
}
try {
	$null = New-Item -ItemType Directory -Path $language -Force
	Set-Content -LiteralPath $exceptions -Value '@{ NoTextNeeded = @("External.Exception") }' -Encoding utf8
	Set-Content -LiteralPath (Join-Path $language 'strings.psd1') -Value '@{ Resolved = "text"; Orphan = "unused"; Empty = "" }' -Encoding utf8
	Test-Check "Write-PSFMessage -String 'Resolved'" $true 'resolved key with unrelated orphan'
	Test-Check "Write-PSFMessage -String 'Missing'" $false 'missing direct key'
	Test-Check "Write-PSFMessage -String 'Empty'" $false 'empty direct key'
	Test-Check "Write-PSFMessage -String 'External.Exception'" $true 'NoTextNeeded exception'
	Test-Check '$message = @{ String = "Missing" }; Write-PSFMessage @message' $false 'missing splatted key'
	Test-Check 'param([PsfValidateScript("x", ErrorString="module.Missing")][string] $Value)' $false 'missing attribute key'
	$resolved = (Resolve-Path -LiteralPath $language).Path
	$expected = [IO.Path]::GetFullPath((Join-Path $fixture 'en-us'))
	if ($resolved -ne $expected) { throw 'Unexpected fixture language path.' }
	Remove-Item -LiteralPath $resolved -Recurse -Force
	Test-Check "Write-PSFMessage -String 'Resolved'" $false 'missing language folder'
}
finally {
	if (Test-Path -LiteralPath $fixture) {
		$resolved = (Resolve-Path -LiteralPath $fixture).Path
		$tempParent = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
		if (-not $resolved.StartsWith($tempParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'String fixture escaped the temporary directory.' }
		Remove-Item -LiteralPath $resolved -Recurse -Force
	}
}
