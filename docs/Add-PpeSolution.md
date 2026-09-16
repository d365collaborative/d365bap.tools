---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpeSolution

## SYNOPSIS
Add a solution to a Power Platform environment.

## SYNTAX

```
Add-PpeSolution [-EnvironmentId] <String> [-Publisher] <String> [-Name] <String> [-SystemName] <String>
 [[-Version] <String>] [[-Description] <String>] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Creates a new unmanaged Dataverse solution (solutions) with the bare minimum of required fields.

The publisher is resolved by unique name, friendly name, prefix or id using Get-PpePublisher.
The solution unique name must be unique across the environment.

## EXAMPLES

### EXAMPLE 1
```
Add-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Publisher "contoso" -Name "Contoso Tools" -SystemName "contoso_tools"
```

This will create the "Contoso Tools" solution with version 1.0.0.0 for the "contoso" publisher.

### EXAMPLE 2
```
Add-PpeSolution -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -Publisher "contoso" -Name "Contoso Tools" -SystemName "contoso_tools" -Version "1.0.0.0" -Description "Contoso tools solution"
```

This will create the "Contoso Tools" solution with full details.

## PARAMETERS

### -EnvironmentId
The id of the environment that you want to work against.

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

### -Publisher
The publisher that the solution belongs to.

Can be either the publisher unique name, friendly name, prefix or id.
Use Get-PpePublisher to list available publishers.

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

### -Name
The display / friendly name of the solution.

```yaml
Type: String
Parameter Sets: (All)
Aliases: DisplayName, FriendlyName

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SystemName
The unique name of the solution.
Must be unique across the environment.

```yaml
Type: String
Parameter Sets: (All)
Aliases: UniqueName

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
The initial version of the solution.
Defaults to "1.0.0.0".

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 1.0.0.0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
An optional description of the solution.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
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
Author: Mötz Jensen (@Splaxi)

## RELATED LINKS
