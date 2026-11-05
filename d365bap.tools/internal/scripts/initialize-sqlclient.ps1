<#
    .SYNOPSIS
        Loads the bundled SQL client in its own assembly context.

    .DESCRIPTION
        Preloads managed dependencies and the platform SQL transport without compiling a loader or downloading files.
#>
$sqlClientRoot = Join-Path $script:ModuleRoot 'bin/SqlClient'
$sqlClientContext = [Runtime.Loader.AssemblyLoadContext]::new('d365bap.tools.SqlClient')
$hashSqlAssemblies = @{}
foreach ($file in Get-ChildItem -LiteralPath $sqlClientRoot `
		-Filter '*.dll' `
		-File) {
	$hashSqlAssemblies[$file.Name] = $file.FullName
}
$platform = 'unix'
if ($IsWindows) { $platform = 'win' }
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $sqlClientRoot "runtimes/$platform/lib") `
		-Recurse `
		-Filter '*.dll' `
		-File) {
	$hashSqlAssemblies[$file.Name] = $file.FullName
}
foreach ($name in $hashSqlAssemblies.Keys |
	Where-Object { $_ -ne 'Microsoft.Data.SqlClient.dll' }) {
	$sqlClientContext.LoadFromAssemblyPath($hashSqlAssemblies[$name]) > $null
}
$sqlClientAssembly = $sqlClientContext.LoadFromAssemblyPath($hashSqlAssemblies['Microsoft.Data.SqlClient.dll'])
if ($IsWindows) {
	$architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()
	$nativePath = Join-Path $sqlClientRoot "runtimes/win-$architecture/native/Microsoft.Data.SqlClient.SNI.dll"
	[Runtime.InteropServices.NativeLibrary]::Load($nativePath) > $null
}
$script:SqlClientFactory = $sqlClientAssembly.GetType('Microsoft.Data.SqlClient.SqlClientFactory').GetField('Instance').GetValue($null)
