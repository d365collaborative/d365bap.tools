param (
    $TestPublic = $true,
	
    $TestInternal = $true
)

Import-Module "Pester" -MaximumVersion 4.99.99 -Force

& "$PSScriptRoot\..\d365bap.tools\tests\pester-PSScriptAnalyzer.ps1" `
    -TestPublic $TestPublic `
    -TestInternal $TestInternal