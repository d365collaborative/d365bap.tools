<#
.SYNOPSIS
Clears orphaned UDE configurations and their associated resources.

.DESCRIPTION
This function identifies and removes orphaned UDE configurations, including their package directories, symlinks, and XRef databases.

.PARAMETER Force
Instructs the function to proceed with clearing orphaned configurations.

Nothing happens unless this parameter is supplied.

.PARAMETER IncludePackages
Instructs the function to include package directories in the clearing process.

Please note that package directories might be needed for other environments later on, so to avoid downloading packages again, this parameter is optional.

.EXAMPLE
PS C:\> Clear-UdeOrphanedConfig

This will collect all orphaned UDE configurations and display them, but will not proceed with the clearing process.
It will list the XppConfig directories and XRef databases that are considered orphaned.

.EXAMPLE
PS C:\> Clear-UdeOrphanedConfig -Force

This will remove all orphaned UDE configurations and their associated resources.
It will only process the XppConfig directories and XRef databases that are considered orphaned.

.EXAMPLE
PS C:\> Clear-UdeOrphanedConfig -IncludePackages

This will collect all orphaned UDE configurations, including package directories, and display them, but will not proceed with the clearing process.
It will list the package directories, XppConfig directories, and XRef databases that are considered orphaned.

.EXAMPLE
PS C:\> Clear-UdeOrphanedConfig -IncludePackages -Force

This will remove all orphaned UDE configurations and their associated resources, including package directories.
It will process the package directories, XppConfig directories, and XRef databases that are considered orphaned.
Removing package directories might lead to re-downloading packages later on if they are needed for other environments.

.NOTES
Author: Mötz Jensen (@Splaxi)

#>
function Clear-UdeOrphanedConfig {
    [CmdletBinding()]
    param (
        [switch] $Force,

        [switch] $IncludePackages
    )

    begin {
    }

    process {
        $colConfigs = Get-UdeConfig
        $pathBase = "$env:LOCALAPPDATA\Microsoft\Dynamics365"
        $orphanedDirs = [System.Collections.Generic.List[string]]::new()

        if ($IncludePackages) {
            # We need to find all package directories - directly under the Dynamics365 local app data path
            $pathPackages = "$pathBase\10.*"
            $colPackageDirs = Get-Item -Path $pathPackages | `
                Select-Object -ExpandProperty FullName

            # Then we need to find all active package directories - based on the UDE configs
            $activePackageDirs = @($colConfigs.PackagesLocalDirectory | `
                    ForEach-Object { Split-Path -Path $_ -Parent }) | `
                Select-Object -Unique

            # Finally, we need to find all orphaned package directories
            $colPackageDirs | Where-Object { $_ -notin $activePackageDirs } | ForEach-Object {
                $orphanedDirs.Add($_)
            }
        }

        # We need to find all symlinked runtime package directories - directly under the RuntimeSymLinks path
        $pathSymlinks = "$pathBase\RuntimeSymLinks"
        $colSymlinkDirs = @(Get-ChildItem `
                -Path $pathSymlinks `
                -Directory | `
                Select-Object -ExpandProperty FullName)
        
        # Then we need to find all active symlinked runtime package directories - based on the UDE configs
        $activeSymlinks = @($colConfigs.RuntimePackagesDirectory) | `
            Select-Object -Unique

        # Finally, we need to find all orphaned symlinked runtime package directories
        $colSymlinkDirs | Where-Object { $_ -notin $activeSymlinks } | ForEach-Object {
            $orphanedDirs.Add($_)
        }

        # We need to find all XRef Db directories - directly under the XPPConfig path
        $pathXRefDir = "$pathBase\XPPConfig"
        $colXRefDirs = @(Get-ChildItem -Path $pathXRefDir -Directory | `
                Select-Object -ExpandProperty FullName
        )

        # Finally, we need to find all orphaned XRef Db directories
        $colXRefDirs | Where-Object {
            $(Split-Path -Path "$($_.Split("_")[0])" -Leaf) -notin @($colConfigs.Name) } | ForEach-Object {
            $orphanedDirs.Add($_)
        }
        
        # We need to find all XRef DBs - directly under the LocalDB instance
        $colXRefDbs = Get-UdeXrefDb | Where-Object Name -ne 'SampleXRef'

        # Then we need to find all active XRef DBs - based on the UDE configs
        $activeXRefDbs = @($colConfigs.XRefDatabase) | Select-Object -Unique

        # Finally, we need to find all orphaned XRef DBs
        $orphanedXRefDbs = $colXRefDbs | Where-Object {
            $_.Name -notin $activeXRefDbs
        } | Select-Object -ExpandProperty Name

        if ($orphanedDirs.Count -lt 1 -and $orphanedXRefDbs.Count -lt 1) {
            Write-PSFMessage -Level Host -Message "No orphaned UDE directories or XRef databases found. <c='em'>Nothing to do.</c>"
            return
        }

        if (-not $Force) {
            if ($orphanedDirs.Count -gt 0) {
                Write-PSFMessage -Level Host -Message "The following directories are orphaned and will be removed:"
                $orphanedDirs.ToArray() | ForEach-Object { Write-PSFMessage -Level Host -Message " - <c='em'>$_</c>" }
            }

            if ($orphanedXRefDbs.Count -gt 0) {
                Write-PSFMessage -Level Host -Message "The following XRef databases are orphaned and will be removed:"
                $orphanedXRefDbs | ForEach-Object { Write-PSFMessage -Level Host -Message " - <c='em'>$_</c>" }
            }

            $messageString = "This will remove all listed package directories and XRef DBs. If you are sure, please re-run the command with the <c='em'>-Force</c> parameter."

            Write-PSFMessage -Level Host -Message $messageString -Target Host
            Stop-PSFFunction -Message "Stopping because Force parameter wasn't supplied." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }

        # Proceed with the removal of the directories
        foreach ($dir in $orphanedDirs) {
            Remove-Item -Path $dir `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue `
                -Confirm:$false
        }

        # Ensure that LocalDB sqlservr process is stopped before dropping databases
        $procSql = Get-Process -Name sqlservr `
            -FileVersionInfo `
            -ErrorAction SilentlyContinue

        if ($null -ne $procSql.FileName -and $procSql.FileName -contains "*LocalDB*") {
            Get-Process -Name sqlservr | Stop-Process
        }

        # Proceed with the removal of the directories
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand

        try {
            $sqlConnection.ConnectionString = "Server='(LocalDB)\MSSQLLocalDB';Database='master';Integrated Security='SSPI';Application Name='d365bap.tools'"

            $sqlCommand.Connection = $sqlConnection
            $sqlCommand.CommandTimeout = 0

            $sqlCommand.Connection.Open()

            foreach ($db in $orphanedXRefDbs) {
                $sqlCommand.CommandText = "DROP DATABASE [$db]"
                $sqlCommand.ExecuteNonQuery() > $null
            }

            $sqlCommand.Connection.Close()
        }
        catch {
            Write-PSFMessage -Level Host -Message "Something went wrong while working with the sql server connection objects or the database server threw an unexpected error." -Exception $PSItem.Exception
            Stop-PSFFunction -Message "Stopping because of errors"
            return
        }
        finally {
            if ($sqlCommand.Connection.State -ne [System.Data.ConnectionState]::Closed) {
                $sqlCommand.Connection.Close()
            }

            $sqlCommand.Dispose()
        }
    }
}