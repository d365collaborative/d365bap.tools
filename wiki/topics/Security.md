<!--
topic: d365bap.tools.Security
keywords: security, roles, security roles, rbac, teams, security groups, users, entra, privileges, access level
-->

# Security

The module works with three different role systems. Picking the wrong one is the most common mistake, so start with the question: which "role" do you mean?

- "Who can use this app or environment?" - a Dataverse security role (Ppac commands), or an F&O security role (Fscm commands).
- "Who can administer the platform itself?" - a PPAC RBAC role (Ppac commands), usually for a service principal.

## Dataverse security roles (Ppac)

Roles inside one Power Platform environment, the ones you edit in the PPAC portal:

- New-PpacSecurityRole - create a role.
- Set-PpacSecurityRoleTable / Get-PpacSecurityRoleTable - the table privileges of a role, with an access level per privilege.
- Get-PpacSecurityRole / Get-PpacSecurityRoleMember / Add-PpacSecurityRoleMember - inspect roles and assign them to users.
- Get-PpacTeam / Set-PpacTeamSecurityRole / Add-PpacTeamOnSecurityGroup - teams, including teams created from an Entra security group.
- Set-PpacSecurityGroup - restrict environment access to a security group.
- Add-PpacUser / Get-PpacUser / Remove-PpacUser - users; Add-PpacApplicationUser / Get-PpacApplicationUser for application users.

Access levels translate to Dataverse privilege depths: User is Basic, Business Unit is Local, Parent: Child Business Unit is Deep, and Organization is Global.

## F&O security roles (Fscm)

Roles inside the ERP itself, assigned through its own endpoints:

- Get-FscmSecurityRole / Get-FscmSecurityRoleMember / Add-FscmSecurityRoleMember - inspect and assign ERP roles.
- Add-FscmUser - create an ERP user and assign a role in one step.
- Add-FscmUserFromSecurityGroup - create users from every member of an Entra security group.
- Set-FscmUserAccess - enable or disable user access.
- Add-FscmEntraApplication / Get-FscmEntraApplication - register Entra applications with the ERP.

## PPAC RBAC roles (Ppac)

Administrative roles that gate the Power Platform admin surface itself, granted mainly to service principals, and available at tenant, environment and environment-group scope:

- Get-PpacRbacRole / Get-PpacRbacRoleMember / Get-PpacRbacRoleAssignment - what exists and who holds it.
- Add-PpacRbacRoleMember / Remove-PpacRbacRoleMember - assign or remove, with environment and environment-group scoped variants.

## Entra lookups (Graph)

Get-GraphGroupMember expands an Entra security group into its members, which feeds the group-driven flows in both Dataverse and ERP user management.

Typical flow: Get-GraphGroupMember to see who is in the group, then Add-FscmUserFromSecurityGroup or Add-PpacTeamOnSecurityGroup to act on all of them.
