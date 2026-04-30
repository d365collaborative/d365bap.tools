param (
    $TestGeneral = $true,
	
    $TestFunctions = $true,

    $Exclude = ""
)


# Import-Module "Pester" -MaximumVersion 4.99.99 -Force

& "$PSScriptRoot\..\d365bap.tools\tests\pester.ps1"  `
    -TestGeneral $TestGeneral `
    -TestFunctions $TestFunctions `
    -Exclude $Exclude
