---
external help file: d365bap.tools-help.xml
Module Name: d365bap.tools
online version:
schema: 2.0.0
---

# Add-PpePublisher

## SYNOPSIS
Add a publisher to a Power Platform environment.

## SYNTAX

```
Add-PpePublisher [-EnvironmentId] <String> [-UniqueName] <String> [-FriendlyName] <String> [-Prefix] <String>
 [[-OptionValuePrefix] <Int32>] [[-Description] <String>] [[-EmailAddress] <String>]
 [[-SupportingWebsiteUrl] <String>] [[-AddressLine1] <String>] [[-AddressLine2] <String>]
 [[-AddressLine3] <String>] [[-AddressCity] <String>] [[-AddressStateOrProvince] <String>]
 [[-AddressPostalCode] <String>] [[-AddressCountry] <String>] [[-AddressPhone] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Creates a new Dataverse publisher (publishers) with the bare minimum of required fields.

The cmdlet is idempotent and works as an upsert keyed on UniqueName.
If a publisher
with the same unique name already exists, it is updated in place with the supplied
values instead of failing.
Only values explicitly supplied by the caller are updated -
omitted optional values are left untouched on existing publishers.

Requires the unique name, display name, customization prefix and option value prefix.
The option value prefix defaults to a random value between 10000 and 99999 when omitted on create.
It is left untouched on update when omitted.

## EXAMPLES

### EXAMPLE 1
```
Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont"
```

This will create the "Contoso" publisher with the prefix "cont" and a random option value prefix.

### EXAMPLE 2
```
Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont" -OptionValuePrefix 12345 -Description "Contoso publisher"
```

This will create the "Contoso" publisher with full details.

### EXAMPLE 3
```
Add-PpePublisher -EnvironmentId "eec2c11a-a4c7-4e1d-b8ed-f62acc9c74c6" -UniqueName "contoso" -FriendlyName "Contoso" -Prefix "cont" -AddressLine1 "One Microsoft Way" -AddressCity "Redmond" -AddressCountry "USA" -EmailAddress "publisher@contoso.com"
```

This will update the existing "contoso" publisher with address details if it already exists, or create it with address details if it does not exist.

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

### -UniqueName
The unique name of the publisher.
Must be unique across the environment.

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

### -FriendlyName
The display / friendly name of the publisher.

```yaml
Type: String
Parameter Sets: (All)
Aliases: DisplayName

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Prefix
The customization prefix used for new entities, attributes and relationships for solutions associated with this publisher.

```yaml
Type: String
Parameter Sets: (All)
Aliases: CustomizationPrefix

Required: True
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OptionValuePrefix
The default option value prefix used for newly created options for solutions associated with this publisher.

Must be between 10000 and 99999.
Defaults to a random value in that range when omitted.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases: CustomizationOptionValuePrefix

Required: False
Position: 5
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Description
An optional description of the publisher.

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

### -EmailAddress
An optional email address for the publisher.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SupportingWebsiteUrl
An optional supporting website URL for the publisher.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Website

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressLine1
An optional first street line for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressLine2
An optional second street line for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressLine3
An optional third street line for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressCity
An optional city for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressStateOrProvince
An optional state or province for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 13
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressPostalCode
An optional ZIP / postal code for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 14
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressCountry
An optional country / region for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 15
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AddressPhone
An optional phone number for address 1.

```yaml
Type: String
Parameter Sets: (All)
Aliases: Phone, Telephone1

Required: False
Position: 16
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
