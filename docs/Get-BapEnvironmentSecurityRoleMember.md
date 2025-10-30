---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Get-BapEnvironmentSecurityRoleMember

## SYNOPSIS
Get users/members from security role

## SYNTAX

```
Get-BapEnvironmentSecurityRoleMember [-EnvironmentId] <String> [-SecurityRoleId] <String> [[-UserId] <String>]
 [-IncludePpacApplications] [-AsExcelOutput] [<CommonParameters>]
```

## DESCRIPTION
Enables the user to fetch all users/members from the security role in the environment

Utilizes the built-in "roles" OData entity

Allows the user to include all users/members, based on those who has the ApplicationId property filled

## EXAMPLES

### EXAMPLE 1
```
Get-BapEnvironmentSecurityRoleMember -EnvironmentId eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6 -SecurityRoleId 'System Administrator'
```

This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.

Sample output:
Email                          Name                           AppId                SystemUserId
-----                          ----                           -----                ------------
d365admin@contoso.com          # D365Admin                                         58879b65-65ca-45f7-bf8e-9550e241083e
crmoln2@microsoft.com          Delegated Admin                                     58879b65-65ca-47f5-bf8e-9550e241083e

### EXAMPLE 2
```
Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator'
```

This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.

Sample output:
Email                          Name                           AppId                SystemUserId
-----                          ----                           -----                ------------
d365admin@contoso.com          # D365Admin                                         58879b65-65ca-45f7-bf8e-9550e241083e
crmoln2@microsoft.com          Delegated Admin                                     58879b65-65ca-47f5-bf8e-9550e241083e

### EXAMPLE 3
```
Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator' -UserId '*@contoso.com'
```

This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.
It will only include the ones that have an email address that contains '@contoso.com'.

Sample output:
Email                          Name                           AppId                SystemUserId
-----                          ----                           -----                ------------
d365admin@contoso.com          # D365Admin                                         58879b65-65ca-45f7-bf8e-9550e241083e

### EXAMPLE 4
```
Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator' -IncludePpacApplications
```

This will fetch all users that are members of the security role 'System Administrator' from the environment.
It will include the ones with the ApplicationId property filled.

Sample output:
Email                          Name                           AppId                SystemUserId
-----                          ----                           -----                ------------
CatalogServiceEur@onmicrosoft… # CatalogServiceEur            ac22509c-8d51-4169-… 330297ba-cbf6-ed11-8849-6045bd8e42bc
CCaaSCRMClient@onmicrosoft.com # CCaaSCRMClient               edfdd43b-45b9-498b-… f4f45a4b-f8b7-ed11-9886-6045bd8e42bc
d365admin@contoso.com          # D365Admin                                         58879b65-56ca-45f7-bf8e-9550e241083e

### EXAMPLE 5
```
Get-BapEnvironmentSecurityRoleMember -EnvironmentId *uat* -SecurityRoleId 'System Administrator' -AsExcelOutput
```

This will fetch all oridinary users that are members of the security role 'System Administrator' from the environment.
Will output all details into an Excel file, that will auto open on your machine.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against

This can be obtained from the Get-BapEnvironment cmdlet

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SecurityRoleId
The id of the security role that you want to work against

This can be obtained from the Get-BapEnvironmentSecurityRole cmdlet

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UserId
The (SystemUser)Id or email of the user that you want to filter on

This can be obtained from the Get-BapEnvironmentUser cmdlet

Default value is "*" - which translates into all available users/members

Wildcard search is supported

```yaml
Type: String
Parameter Sets: (All)
Aliases: Email

Required: False
Position: 3
Default value: *
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludePpacApplications
Instruct the cmdlet to include all users that are members of the security role

Simply includes those who has the ApplicationId property filled

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsExcelOutput
Instruct the cmdlet to output all details directly to an Excel file

This makes it easier to deep dive into all the details returned from the API, and makes it possible for the user to persist the current state

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
