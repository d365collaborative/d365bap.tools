# Script to generate the parameter unit tests.
# based on https://gist.github.com/Splaxi/2a24fc3c5193089ae7047ac5b8f104db
# See also https://github.com/d365collaborative/d365fo.tools/wiki/Building-tools
$path = "$PSScriptRoot\..\d365bap.tools"

Import-Module $path -Force

$excludeCommands = @()

$commandsRaw = Get-Command -Module d365bap.tools -CommandType Function

if ($excludeCommands.Count -gt 0) {
    $commands = $commandsRaw | Select-String -Pattern $excludeCommands -SimpleMatch -NotMatch

} else {
    $commands = $commandsRaw
}

Remove-Item -Path "$path\tests\functions\*.Tests.ps1"

foreach ( $commandName in $commands) {
    Invoke-PSMDTemplate CommandTest -OutPath "$path\tests\functions" -Name $commandName -Force
}

# Standard parameters carry no per-command contract. Drop their generated
# tests (see d365bap.tools/functions/AGENTS.md). A hand-declared -Force
# switch is part of the cmdlet signature, so it keeps its test.
$skipParameters = @('Confirm', 'WhatIf')

Get-ChildItem -Path "$path\tests\functions\*.Tests.ps1" -Recurse -File | Set-PSMDEncoding

Get-ChildItem -Path "$path\tests\functions\*.Tests.ps1" -File | ForEach-Object {
    $content = [IO.File]::ReadAllText($_.FullName) -replace '\r?\n', "`r`n"
    foreach ($skipParameter in $skipParameters) {
        $content = $content -replace "(?ms)^\t+It 'Should have the expected parameter $skipParameter' \{.*?\r?\n\t+\}\r?\n", ''
    }
    [IO.File]::WriteAllText($_.FullName, $content, [Text.UTF8Encoding]::new($true))
}
