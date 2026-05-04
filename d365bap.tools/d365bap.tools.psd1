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
	FormatsToProcess  = @(
		'xml\formats\table\D365Bap.Tools.BapD365App.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.BapEnvironmentOperation.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.Compare.PpacD365App.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.Compare.PpacUser.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.Compare.VirtualEntity.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.DeployTemplate.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.Environment.Integration.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.FnOSecurityRoleMember.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.FscmEntraApplication.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.FscmOdataEntity.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.FscmRole.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.FscmUser.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.PpacApplicationUser.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacD365App.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacD365OperationHistory.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacEnvironment.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacLocation.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacPowerApp.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacRbacRoleAssignment.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacRole.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacSolution.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacTeam.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.PpacUser.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.PpeOdataEntity.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.UdeConfig.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.UdeEnvironmentModule.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.UdeEnvironmentPackage.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.VirtualEntity.Table.Format.ps1xml',

		'xml\formats\table\D365Bap.Tools.VsPackageDeploy.Table.Format.ps1xml',
		'xml\formats\table\D365Bap.Tools.VsPpacExtensionHistory.Table.Format.ps1xml',

		'xml\formats\list\D365Bap.Tools.BapEnvironmentOperation.List.Format.ps1xml',

		'xml\formats\list\D365Bap.Tools.FnOSecurityRoleMember.List.Format.ps1xml',

		'xml\formats\list\D365Bap.Tools.FscmOdataEntity.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.FscmRole.List.Format.ps1xml',

		'xml\formats\list\D365Bap.Tools.PpacAdminManagementApplication.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.PpacD365OperationHistory.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.PpacEnvironment.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.PpacRbacRole.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.PpacTeam.List.Format.ps1xml',

		'xml\formats\list\D365Bap.Tools.PpeOdataEntity.List.Format.ps1xml',

		'xml\formats\list\D365Bap.Tools.UdeCredentialCache.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.UdeDatabaseJit.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.UdeDeveloperFile.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.UdeEnvironment.List.Format.ps1xml',
		'xml\formats\list\D365Bap.Tools.UdeEnvironmentPackage.List.Format.ps1xml'
	)
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Add-FscmEntraApplication'
		, 'Add-FscmSecurityRoleMember'
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
		
		, 'Get-FscmEntraApplication'
		, 'Get-FscmOdata'
		, 'Get-FscmOdataEntity'
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
		
		, 'Get-PpeOdata'
		, 'Get-PpeOdataEntity'
		
		, 'Get-PpeSolution'
		, 'Get-PpeSolutionHistory'
		
		, 'Get-UdeConfig'
		, 'Get-UdeConnection'
		, 'Get-UdeCredentialCache'
		, 'Get-UdeDbJit'
		, 'Get-UdeDbJitCache'
		, 'Get-UdeDeveloperFile'
		, 'Get-UdeVsPackageDeploy'
		, 'Get-UdeVsPowerPlatformExtensionHistory'
		, 'Get-UdeXrefDb'
		
		, 'Get-UnifiedEnvironment'
		, 'Get-UnifiedEnvironmentModule'
		, 'Get-UnifiedEnvironmentPackage'
		
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
		
		, 'Set-FscmUserAccess'
		
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