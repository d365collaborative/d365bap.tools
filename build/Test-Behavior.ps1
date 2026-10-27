<#
.SYNOPSIS
    Runs offline user behavior tests.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module Pester -ErrorAction Stop
$config = [PesterConfiguration]::Default
$config.Run.Path = Join-Path $PSScriptRoot '../d365bap.tools/tests/behavior'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Normal'
$result = Invoke-Pester -Configuration $config
if ($result.Result -ne 'Passed' -or $result.TotalCount -eq 0) { throw 'Behavioral regression tests failed or did not run.' }
