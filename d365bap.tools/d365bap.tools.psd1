@{
	# Script module or binary module file associated with this manifest
	RootModule        = 'd365bap.tools.psm1'
	
	# Version number of this module.
	ModuleVersion     = '0.0.10'
	
	# ID used to uniquely identify this module
	GUID              = 'adfc3aa2-1269-4648-a3d6-0342d5ef00bf'
	
	# Author of this module
	Author            = 'Mötz Jensen'
	
	# Company or vendor of this module
	CompanyName       = 'Essence Solutions'
	
	# Copyright statement for this module
	Copyright         = 'Copyright (c) 2024 Mötz Jensen'
	
	# Description of the functionality provided by this module
	Description       = 'Tools used for Business Application Platform, One Dynamics One Platform - D365FO + Dataverse'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.0'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules   = @(
		@{ ModuleName = 'PSFramework'; ModuleVersion = '1.9.310' }
		, @{ ModuleName = 'ImportExcel'; ModuleVersion = '7.8.6' }
		, @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.12.4' }
	)
	
	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @('bin\d365bap.tools.dll')
	
	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @('xml\d365bap.tools.Types.ps1xml')
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess  = @('xml\d365bap.tools.Format.ps1xml')
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Compare-BapEnvironmentD365App'
		, 'Compare-BapEnvironmentUser'
		
		, 'Confirm-BapEnvironmentIntegration'
		
		, 'Get-BapEnvironment'
		, 'Get-BapEnvironmentApplicationUser'

		, 'Get-BapEnvironmentD365App'
		
		, 'Get-BapEnvironmentUser'

		, 'Get-BapEnvironmentVirtualEntity'
		
		, 'Invoke-BapEnvironmentInstallD365App'

		, 'Set-BapEnvironmentVirtualEntity'
	)
	
	# Cmdlets to export from this module
	CmdletsToExport   = ''
	
	# Variables to export from this module
	VariablesToExport = ''
	
	# Aliases to export from this module
	AliasesToExport   = ''
	
	# List of all modules packaged with this module
	ModuleList        = @()
	
	# List of all files packaged with this module
	FileList          = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData       = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			# Tags = @()
			
			# A URL to the license for this module.
			# LicenseUri = ''
			
			# A URL to the main website for this project.
			# ProjectUri = ''
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# ReleaseNotes of this module
			# ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}