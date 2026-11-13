$scbTenantEntitlement = {
	'AI', 'AppPass', 'AppPassForTeams', 'Invoice',
	'MCSSessions', 'MCSMessages',
	'PAHostedRPA', 'PAUnattendedRPA', 'PerFlowPlan',
	'PortalAddOns', 'PortalLogins', 'PortalViews',
	'PowerPagesAuthenticated', 'PowerPagesAnonymous',
	'PowerAutomatePerProcess', 'ProcessMiningDataStorage',
	'SCMessages', 'VAConversations',
	'W365APAYGO', 'TenantM365Copilot'
}

Register-PSFTeppScriptblock -Name "d365bap.tools.tepp.tenant.entitlement" -ScriptBlock $scbTenantEntitlement -Mode Simple
