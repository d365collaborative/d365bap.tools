<!--
topic: d365bap.tools.Policies
keywords: policies, dlp, acp, rule based, governance, environment groups, tenant policy
-->

# Policies

Governance policies come in three families - DLP, ACP and rule-based - and each family can be applied at three scopes: the tenant, an environment group, or a single environment.

## DLP policies

Data loss prevention policies control which connectors may be used together. The module manages them end to end:

- New-PpacTenantDlpPolicy / Set-PpacTenantDlpPolicy / Remove-PpacTenantDlpPolicy / Get-PpacTenantDlpPolicy - tenant level.
- New-PpacEnvironmentDlpPolicy / Set-PpacEnvironmentDlpPolicy / Remove-PpacEnvironmentDlpPolicy / Get-PpacEnvironmentDlpPolicy - environment level.

## ACP policies

App control policies restrict which apps can run in an environment. The tenant holds the policy definitions; environments and environment groups receive assignments:

- New-PpacTenantAcpPolicy / Set-PpacTenantAcpPolicy / Remove-PpacTenantAcpPolicyRuleSet / Get-PpacTenantAcpPolicy - define at the tenant.
- Add-PpacEnvironmentAcpPolicyAssignment / Get-PpacEnvironmentAcpPolicy - assign and inspect per environment.
- Add-PpacEnvironmentGroupAcpPolicyAssignment / Get-PpacEnvironmentGroupAcpPolicy - assign and inspect per environment group.

## Rule-based policies

Rule-based policies apply governance rules across many environments at once instead of one by one:

- New-PpacTenantRuleBasedPolicy / Set-PpacTenantRuleBasedPolicy / Remove-PpacTenantRuleBasedPolicyRuleSet / Get-PpacTenantRuleBasedPolicy - the tenant rule sets.
- Add-PpacEnvironmentRuleBasedPolicyAssignment / Get-PpacEnvironmentRuleBasedPolicy - environment scope.
- Add-PpacEnvironmentGroupRuleBasedPolicyAssignment / Get-PpacEnvironmentGroupRuleBasedPolicy - environment-group scope.

## Environment groups

Groups are the container that makes the group-scoped policies useful: put related environments in one group (Get-PpacEnvironmentGroup), then assign one policy or rule set to all of them. An environment added to a group becomes a managed environment.

```pwsh
Get-PpacEnvironmentGroup
Get-PpacEnvironmentGroupRuleBasedPolicy
```

Platform administration roles for the admin surface itself are a separate system, see [Security](Security).
