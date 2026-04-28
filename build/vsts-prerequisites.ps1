param (
    [string]
    $Repository = 'PSGallery'
)

$modules = @("Pester", "PSFramework", "PSModuleDevelopment", "PSScriptAnalyzer")

# Automatically add missing dependencies
$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\d365bap.tools\d365bap.tools.psd1"
foreach ($dependency in $data.RequiredModules) {
    if ($dependency -is [string]) {
        if ($modules -contains $dependency) { continue }
        $modules += $dependency
    }
    else {
        if ($modules -contains $dependency.ModuleName) { continue }
        $modules += $dependency.ModuleName
    }
}

# foreach ($module in $modules) {
#     Write-Host "Installing $module - $(Get-Date)" -ForegroundColor Cyan
#     Install-Module $module -Force -SkipPublisherCheck -Repository $Repository
#     Import-Module $module -Force -PassThru
# }

Write-Host "Installing modules - $(Get-Date)" -ForegroundColor Cyan
iwr bit.ly/modulefast | iex
Install-ModuleFast 'Pester', 'PSFramework', 'PSModuleDevelopment', 'PSScriptAnalyzer', 'ImportExcel', 'Az.Accounts' -NoProfileUpdate