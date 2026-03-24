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
	# Some commands require PowerShell 7, but the module can still be imported in 5.0
	PowerShellVersion = '5.0'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules   = @(
		@{ ModuleName = 'PSFramework'; ModuleVersion = '1.9.310' }
		, @{ ModuleName = 'ImportExcel'; ModuleVersion = '7.8.6' }
		, @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.17.0' }
	)
	
	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @('bin\d365bap.tools.dll')
	
	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @('xml\d365bap.tools.Types.ps1xml')
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess  = @('xml\d365bap.tools.Format.ps1xml')
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Add-FscmSecurityRoleMember'
		, 'Add-FscmUser'
		, 'Add-FscmUserFromSecurityGroup'
		
		, 'Add-PpacAdminManagementApplication'
		, 'Add-PpacApplicationUser'
		
		, 'Add-PpacSecurityRoleMember'
		, 'Add-PpacTeamOnSecurityGroup'
		
		, 'Add-UdeWindowsDefenderRules'
		
		, 'Clear-UdeCredentialCache'
		, 'Clear-UdeDbJitCache'
		, 'Clear-UdeOrphanedConfig'
		
		, 'Compare-BapEnvironmentD365App'
		, 'Compare-BapEnvironmentUser'
		, 'Compare-BapEnvironmentVirtualEntity'
		
		, 'Confirm-BapEnvironmentIntegration'
		, 'Confirm-UdeVs2022Installation'
		
		, 'Get-BapEnvironment'
		, 'Get-BapEnvironmentD365App'
		, 'Get-BapEnvironmentLinkEnterprisePolicy'
		, 'Get-BapEnvironmentOperation'
		, 'Get-BapEnvironmentPowerApp'
		, 'Get-BapEnvironmentVirtualEntity'
		
		, 'Get-BapTenant'
		, 'Get-BapTenantDetail'
		
		, 'Get-FscmSecurityRole'
		, 'Get-FscmSecurityRoleMember'
		, 'Get-FscmUser'
		
		, 'Get-GraphGroupMember'
		
		, 'Get-PpacAdminManagementApplication'
		, 'Get-PpacApplicationUser'
		, 'Get-PpacD365App'
		, 'Get-PpacD365OperationHistory'
		, 'Get-PpacD365PlatformUpdate'
		, 'Get-PpacDeployLocation'
		, 'Get-PpacRbacRole'
		, 'Get-PpacRbacRoleMember'

		, 'Get-PpacSecurityRole'
		, 'Get-PpacSecurityRoleMember'
		, 'Get-PpacTeam'
		, 'Get-PpacUser'
		
		, 'Get-PpeSolution'
		, 'Get-PpeSolutionHistory'
		
		, 'Get-UdeConfig'
		, 'Get-UdeConnection'
		, 'Get-UdeCredentialCache'
		, 'Get-UdeDbJit'
		, 'Get-UdeDbJitCache'
		, 'Get-UdeDeveloperFile'
		, 'Get-UdeEnvironmentModule'
		, 'Get-UdeEnvironmentPackage'
		, 'Get-UdeVsPackageDeploy'
		, 'Get-UdeVsPowerPlatformExtensionHistory'
		, 'Get-UdeXrefDb'
		
		, 'Get-UnifiedEnvironment'
		
		, 'Invoke-BapEnvironmentInstallD365App'
		, 'Invoke-BapInstallAzCopy'
		
		, 'Invoke-PpacD365AppInstall'
		, 'Invoke-PpacD365PlatformUpdate'
		
		, 'Invoke-PpePublishAllCustomizations'
		
		, 'New-D365DevConfig',
		, 'New-UnifiedEnvironment'
		
		, 'Remove-BapTenantDetail'
		
		, 'Set-BapAzCopyPath'
		
		, 'Set-BapEnvironmentLinkEnterprisePolicy'
		, 'Set-BapEnvironmentVirtualEntity'
		, 'Set-BapTenantDetail'
		
		, 'Set-FscmUser'
		
		, 'Set-PpacAdminMode'

		, 'Set-PpacRbacContext'
		, 'Add-PpacRbacRoleMember'

		, 'Set-PpacSecurityGroup'
		, 'Set-PpacTeamSecurityRole'
		
		, 'Set-UdeConfig'
		, 'Set-UdeDbJitCache'
		, 'Set-UdeEnvironmentInSession'
		
		, 'Start-UdeDatabaseRefresh'
		, 'Start-UdeDbSsms'
		
		, 'Switch-BapTenant'
		
		, 'Update-BapEnvironmentVirtualEntityMetadata'
		
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