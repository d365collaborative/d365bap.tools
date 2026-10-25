<#
    .SYNOPSIS
        Regenerates the parameter unit tests.

    .DESCRIPTION
        Regenerates every Tests.ps1 file from the current cmdlets. Fully automated, do not hand-edit the output.
#>
[CmdletBinding()]
param()

$path = "$PSScriptRoot\..\d365bap.tools"

Import-Module $path -Force

$excludeCommands = @()

$commandsRaw = Get-Command -Module d365bap.tools -CommandType Function

if ($excludeCommands.Count -gt 0) {
	$commands = $commandsRaw | Select-String -Pattern $excludeCommands -SimpleMatch -NotMatch

}
else {
	$commands = $commandsRaw
}

Remove-Item -Path "$path\tests\functions\*.Tests.ps1"

foreach ( $commandName in $commands) {
	Invoke-PSMDTemplate CommandTest -OutPath "$path\tests\functions" -Name $commandName -Force
}

$skipParameters = @('Confirm', 'WhatIf', 'ProgressAction')

Get-ChildItem -Path "$path\tests\functions\*.Tests.ps1" -Recurse -File | Set-PSMDEncoding

Get-ChildItem -Path "$path\tests\functions\*.Tests.ps1" -File | ForEach-Object {
	$content = [IO.File]::ReadAllText($_.FullName) -replace '\r?\n', "`r`n"
	foreach ($skipParameter in $skipParameters) {
		$content = $content -replace "(?ms)^\t+It 'Should have the expected parameter $skipParameter' \{.*?\r?\n\t+\}\r?\n", ''
		$content = $content -replace " -$skipParameter(?=\s|$)", ''
	}
	$content = ($content -split "`r`n" | ForEach-Object { "$_".TrimEnd() }) -join "`r`n"
	$content = $content.TrimEnd() + "`r`n"
	[IO.File]::WriteAllText($_.FullName, $content, [Text.UTF8Encoding]::new($true))
}
