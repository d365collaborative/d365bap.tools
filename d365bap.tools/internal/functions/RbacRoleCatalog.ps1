function Get-BapRbacRoleCachePath {
	<#
    .SYNOPSIS
        Returns the user role catalog path.

    .DESCRIPTION
        Keeps refreshed definitions outside the installed module.

    .EXAMPLE
        PS C:\> Get-BapRbacRoleCachePath

        Shows the user cache path.
    #>
	[CmdletBinding()]
	[OutputType([string])]
	param ()

	$base = if ($env:APPDATA) {
		$env:APPDATA
	}
 else {
		Join-Path $HOME '.config'
	}
	Join-Path (Join-Path $base 'd365bap.tools') 'rbac-roles.json'
}

function Get-BapRbacRoleCatalog {
	<#
    .SYNOPSIS
        Reads locally cached role definitions.

    .DESCRIPTION
        Uses the refreshed catalog or bundled definitions without network access.

    .EXAMPLE
        PS C:\> Get-BapRbacRoleCatalog

        Lists locally available role definitions.
    #>
	[CmdletBinding()]
	[OutputType([pscustomobject[]])]
	param ()

	$misc = Get-PSFConfigValue -FullName 'd365bap.tools.internal.misc.path'
	foreach ($itemPath in @((Get-BapRbacRoleCachePath), (Join-Path $misc 'Ppac.Rbac.Roles.json'))) {
		try {
			$tmpRoles = @(Get-Content -LiteralPath $itemPath `
					-Raw `
					-ErrorAction Stop |
				ConvertFrom-Json -ErrorAction Stop)
			$tmpValid = $tmpRoles.Count -gt 0
			foreach ($itemRole in $tmpRoles) {
				if (-not $itemRole.roleDefinitionName) { $tmpValid = $false; break }
				if (-not [guid]::TryParse("$($itemRole.roleDefinitionId)", [ref]([guid]::Empty))) { $tmpValid = $false; break }
			}
			if ($tmpValid) { $tmpRoles; return }
		}
		catch { continue }
	}
}

function Save-BapRbacRoleCatalog {
	<#
    .SYNOPSIS
        Saves role definitions in the user cache.

    .DESCRIPTION
        Validates and atomically replaces the catalog to retain the last usable snapshot.

    .PARAMETER Roles
        Role definitions returned by the authorization API.

    .EXAMPLE
        PS C:\> Save-BapRbacRoleCatalog -Roles $definitions

        Stores retrieved role definitions.
        It uses -Roles to supply the catalog.
    #>
	[CmdletBinding()]
	[OutputType([void])]
	param ([Parameter(Mandatory = $true)][object[]] $Roles)

	if (-not $Roles.Count) { throw 'Invalid role catalog.' }
	foreach ($itemRole in $Roles) {
		if (-not $itemRole.roleDefinitionName) { throw 'Invalid role catalog.' }
		if (-not [guid]::TryParse("$($itemRole.roleDefinitionId)", [ref]([guid]::Empty))) { throw 'Invalid role catalog.' }
	}
	$path = Get-BapRbacRoleCachePath
	$temporary = "$path.$([guid]::NewGuid()).tmp"
	try {
		New-Item -ItemType Directory `
			-Path (Split-Path -Parent $path) `
			-Force `
			-ErrorAction Stop > $null

		ConvertTo-Json -InputObject $Roles `
			-Depth 10 |
		Set-Content -LiteralPath $temporary `
			-Encoding utf8 `
			-ErrorAction Stop

		Move-Item -LiteralPath $temporary `
			-Destination $path `
			-Force `
			-ErrorAction Stop
	}
	finally {
		if (Test-Path -LiteralPath $temporary) {
			Remove-Item -LiteralPath $temporary `
				-Force
		}
	}
}
