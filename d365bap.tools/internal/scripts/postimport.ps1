<#
    .SYNOPSIS
        Lists files loaded after module import.
        
    .DESCRIPTION
        Every path listed here is dot-sourced by the importer. Only paths are listed.
#>
[CmdletBinding()]
param()

$moduleRoot = Split-Path (Split-Path $PSScriptRoot)

(Get-ChildItem "$moduleRoot\internal\configurations\*.ps1" -ErrorAction Ignore).FullName

(Get-ChildItem "$moduleRoot\internal\scriptblocks\*.ps1" -ErrorAction Ignore).FullName

"$moduleRoot\internal\sdk\runtime.ps1"
"$moduleRoot\internal\scripts\initialize-sdk.ps1"

"$moduleRoot\internal\sdk\provisioning.ps1"

"$moduleRoot\internal\sdk\token-preload.ps1"

"$moduleRoot\internal\sdk\finopsversion-preload.ps1"

(Get-ChildItem "$moduleRoot\internal\tepp\*.tepp.ps1" -ErrorAction Ignore).FullName

"$moduleRoot\internal\tepp\assignment.ps1"

"$moduleRoot\internal\scripts\sdk-completion.ps1"

"$moduleRoot\internal\scripts\license.ps1"
