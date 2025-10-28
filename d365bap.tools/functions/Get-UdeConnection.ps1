<#
.SYNOPSIS
Retrieves the UDE connection information.

.DESCRIPTION
This function retrieves the connection information that is currently used by Visual Studio for the User Development Environment (UDE).

.PARAMETER Path
The path to the UDE configuration file.

Defaults to CRMDeveloperToolKit which is the tool used by Visual Studio to communicate with Dynamics 365 / Power Platform environments.

.EXAMPLE
PS C:\> Get-UdeConnection

This will retrieve the UDE connection information.

.NOTES
Author: Mötz Jensen (@Splaxi)
#>
function Get-UdeConnection {
    [CmdletBinding()]
    param (
        [string] $Path = "$env:APPDATA\Microsoft\CRMDeveloperToolKit",

        [switch] $AsExcelOutput
    )

    begin {
        $curConfig = Get-ChildItem -Path "$Path\*.config" | Select-Object -First 1 -ExpandProperty FullName

        if ($null -eq $curConfig) {
            $messageString = "The configuration file was not found. Make sure that the <c='em'>'$Path'</c> is pointing to the correct location of the CRMDeveloperToolKit."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because the configuration file was not found." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        [xml]$xmlConfig = Get-Content -Path $curConfig

        # Build hashtable of key-value pairs
        $props = @{}
        foreach ($add in $($xmlConfig.configuration.appSettings.add)) {
            $props[$add.key] = $add.value
        }

        $resCol = @(
            [PSCustomObject]$props | Select-PSFObject -TypeName 'D365Bap.Tools.UdeConnection' `
                "UserId as Upn",
            @{Name = "ConnectionUri"; Expression = {
                    $temp = [uri]$_.DirectConnectionUri;
                    $temp.Scheme + "://" + $temp.Host
                }
            },
            @{Name = "PpacEnvUri"; Expression = {
                    $temp = [uri]$_.DirectConnectionUri;
                    ($temp.Scheme + "://" + $temp.Host).Replace("api.", "")
                }
            },
            *)

        if ($AsExcelOutput) {
            $resCol | Export-Excel
            return
        }

        $resCol
    }
    
    end {
    }
}