---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# New-PpacSecurityRole

## SYNOPSIS
Create a new security role in a given environment.

## SYNTAX

```
New-PpacSecurityRole [-EnvironmentId] <String> [-Name] <String> [-Description] <String> [-AppliesTo] <String>
 [-SummaryOfCoreTablePrivileges] <String> [[-MemberPrivilegeInheritance] <String>]
 [-IncludeAppOpenerPrivileges] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
This cmdlet creates a new security role in a given Power Platform environment.

It mimics the "Create New Role" experience of the security role editor in the Power Platform admin center, including the member privilege inheritance option and the option to include the App Opener privileges needed for running Model-Driven apps.

The role is created in the root business unit of the environment, which makes the role available across all business units.
Only roles in the root business unit can be modified.

The role is created without any table privileges, unless the App Opener privileges are included.

## EXAMPLES

### EXAMPLE 1
```
New-PpacSecurityRole -EnvironmentId "ContosoEnv" -Name "Monitoring Reader" -Description "Read access for monitoring" -AppliesTo "Monitoring users" -SummaryOfCoreTablePrivileges "Read access to monitoring tables"
```

This command creates the security role "Monitoring Reader" in the environment "ContosoEnv".
The role is created in the root business unit of the environment.
The role is documented with a description, the type of users it applies to and a summary of its core table privileges.
The role is created without any table privileges.

### EXAMPLE 2
```
New-PpacSecurityRole -EnvironmentId "ContosoEnv" -Name "Monitoring Reader" -Description "Read access for monitoring" -AppliesTo "Monitoring users" -SummaryOfCoreTablePrivileges "Read access to monitoring tables" -MemberPrivilegeInheritance "TeamPrivilegesOnly" -IncludeAppOpenerPrivileges
```

This command creates the security role "Monitoring Reader" in the environment "ContosoEnv".
Team members will get all team privileges by default, when the role is assigned to a team.
It will include the App Opener privileges for running Model-Driven apps, copied from the built-in "App Opener" security role.

## PARAMETERS

### -EnvironmentId
The ID of the environment to create the security role in.

Can be either the environment name, the environment GUID (PPAC) or the LCS environment ID.

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

### -Name
The name of the security role that you want to create.

```yaml
Type: String
Parameter Sets: (All)
Aliases: RoleName

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
The description of the security role.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AppliesTo
The description of the type of users the security role applies to.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SummaryOfCoreTablePrivileges
The summary of the core table privileges of the security role.

It is saved in the "summaryofcoretablepermissions" column of the security role.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MemberPrivilegeInheritance
The member privilege inheritance that is used when the security role is assigned to a team.

Valid options:
"DirectUserAndTeamPrivileges" - Team members can inherit team privileges directly, based on the Direct User (Basic) access level.
"TeamPrivilegesOnly" - Team members get all team privileges by default.

The default value is "DirectUserAndTeamPrivileges".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: DirectUserAndTeamPrivileges
Accept pipeline input: False
Accept wildcard characters: False
```

### -IncludeAppOpenerPrivileges
Instructs the cmdlet to include the App Opener privileges for running Model-Driven apps.

The privileges are copied from the built-in "App Opener" security role in the environment.

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

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Object[]
## NOTES
Author: Trygve Bechsgaard

## RELATED LINKS
