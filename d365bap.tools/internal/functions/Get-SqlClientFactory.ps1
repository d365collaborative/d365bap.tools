<#
    .SYNOPSIS
        Gets the bundled SQL client factory.

    .DESCRIPTION
        Loads the factory on demand. The factory isolates the driver dependencies from other modules.

    .EXAMPLE
        PS C:\> Get-SqlClientFactory

        Returns the SQL client factory without installing or downloading external tools.
#>
function Get-SqlClientFactory {
	[CmdletBinding()]
	[OutputType([System.Data.Common.DbProviderFactory])]
	param ()

	if (-not ('D365Bap.Tools.SqlClient.ConnectionFactory' -as [type])) {
		$assemblyPath = Join-Path $script:ModuleRoot 'bin/SqlClient/D365Bap.Tools.SqlClient.dll'
		if (-not (Test-Path -LiteralPath $assemblyPath)) {
			throw 'The bundled SQL client is missing. Reinstall d365bap.tools, or run build/Build-SqlClient.ps1 for a source checkout.'
		}

		[Reflection.Assembly]::LoadFrom($assemblyPath) > $null
	}

	[D365Bap.Tools.SqlClient.ConnectionFactory]::Instance
}
