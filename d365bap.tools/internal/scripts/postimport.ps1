<#
Add all things you want to run after importing the main function code

WARNING: ONLY provide paths to files!

After building the module, this file will be completely ignored, adding anything but paths to files ...
- Will not work after publishing
- Could break the build process
#>

$moduleRoot = Split-Path (Split-Path $PSScriptRoot)

# Load Configurations
(Get-ChildItem "$moduleRoot\internal\configurations\*.ps1" -ErrorAction Ignore).FullName

# Load Scriptblocks
(Get-ChildItem "$moduleRoot\internal\scriptblocks\*.ps1" -ErrorAction Ignore).FullName

# Generate SDK commands before registering completion
"$moduleRoot\internal\sdk\runtime.ps1"
"$moduleRoot\internal\scripts\initialize-sdk.ps1"

# Load provisioning discovery cache before tab expansion reads it
"$moduleRoot\internal\sdk\provisioning.ps1"

# Preload access tokens in the background to warm the token cache
"$moduleRoot\internal\sdk\token-preload.ps1"

# Load Tab Expansion
(Get-ChildItem "$moduleRoot\internal\tepp\*.tepp.ps1" -ErrorAction Ignore).FullName

# Load Tab Expansion Assignment
"$moduleRoot\internal\tepp\assignment.ps1"

# Register SDK completion after the general environment completer
"$moduleRoot\internal\scripts\sdk-completion.ps1"

# Load License
"$moduleRoot\internal\scripts\license.ps1"
