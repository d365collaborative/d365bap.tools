# Output contracts

`PSUseDeclaredOutputType` checks every top-level function in public `functions/`
and `internal/functions/` files, regardless of filename. Nested functions, class methods,
`internal/sdk/`, tests, tepp, and build files are outside declaration scope.
Each checked function declares a nonempty specific output type, or only `[void]`.
Owned literal Select-PSFObject and PSTypeName names must match its declaration;
a nested helper's names cannot satisfy or invalidate the outer declaration.

Accepted declaration examples:

| Result shape | Declaration |
| --- | --- |
| Named PSF object | `[OutputType('D365Bap.Tools.X')]` |
| Named PSF collection | `[OutputType('D365Bap.Tools.X[]')]` |
| Anonymous object | `[OutputType([PSCustomObject])]` |
| Hashtable | `[OutputType([hashtable])]` |
| Scalar | `[OutputType([string])]` or the actual scalar type |
| No success output | `[OutputType([void])]` |

A literal custom name must match the declared name with an optional array suffix.
An anonymous PSCustomObject declaration cannot replace a known named type.
Declarations containing only System.Object/PSObject, including arrays, are too
broad; at least one specific type is required. `[void]` cannot be mixed with
other declared types. This checks metadata and syntactically owned names,
without proving what each execution path emits.

`PSUseStandardPublicOutput` is the single public-output workflow for top-level
functions in public `functions/` files. It merges table-view, collection switch,
and export-block checks into one diagnostic ID. Table views and the Excel switch
are public-function scope; declaration scope is unchanged and the declaration
rule stays separate.

Literal custom names in owned Select-PSFObject projections or PSTypeName
properties require a table view regardless of array declarations. Literal
declared `D365Bap.Tools.*` names also require a view without an inline
projection. The view must have TableControl and select the type name under
`xml/formats/table/*.ps1xml`; a list view does not satisfy the requirement.
Qualified Select-PSFObject and attached literal `-TypeName:'...'` arguments are
recognized. A nested helper cannot supply or invalidate a parent view.

Declared nonscalar collection output additionally requires
`[switch] $AsExcelOutput`. Any array declaration except a scalar array counts
as a collection; `System.Collections.*` declarations count too. A singular
declaration with a valid view does not require the switch. Scalar arrays are
exempt from Excel support, but cannot conceal an explicitly named custom
projection. View checks run even without a parameter block or valid output
declaration; declaration validation reports those independently. A missing
switch reports the complete convention in one diagnostic: add the switch, call
Export-Excel with the full literal worksheet name, then use a bare return. The
export block is not reported again until the switch exists.

Any function that declares the switch must declare an array or
`System.Collections.*` output type. The switch exports a collection, so a
singular declaration is rejected even when the command currently returns one
object; append `[]` to the element type. Scalar arrays such as `[string[]]`
satisfy the array requirement. A function without a declaration is reported by
the declaration rule instead.

Any top-level public function with an AsExcelOutput switch uses one owned
`if ($AsExcelOutput)` block containing an Export-Excel pipeline followed by a
bare return. The block has no else or elseif branch, result-count guard, or trap block.
Export runs synchronously before the return; background pipelines are rejected.
Pass exactly one full `-WorksheetName` parameter with a literal matching the
function name. Splatting, duplicate or abbreviated worksheet
parameters, and computed or variable names are rejected. Extra Export-Excel parameters are
allowed. Forwarding is not an exemption: a forwarding command cannot prove that
the receiving function exports, uses the required worksheet, or returns on the
export path. Each checked public top-level function owns its export block;
nested helpers cannot satisfy it.

```powershell
function Get-Fixture {
    [CmdletBinding()]
    [OutputType('D365Bap.Tools.Known[]')]
    param (
        [switch] $AsExcelOutput
    )

    $resCol = @()

    if ($AsExcelOutput) {
        $resCol | Export-Excel -WorksheetName 'Get-Fixture'
        return
    }

    $resCol | Select-PSFObject -TypeName 'D365Bap.Tools.Known' -Property *
}
```

Dynamic names, deferred scriptblocks, control flow, and runtime output cardinality
are not proven. Custom declarations outside the repository type prefix require
an identifiable inline custom name for view validation. Nested conditional
blocks in the same function are checked syntactically, without proving path
coverage. SDK scope is unchanged.

`PSUseStandardCollectionOutput` and `PSUseStandardExcelExport` were replaced by
`PSUseStandardPublicOutput`. `PSUseDeclaredOutputType` remains separate.

Validation:

```powershell
pwsh -NoProfile -File build/Test-Ps1OutputTypeRule.ps1
pwsh -NoProfile -File build/Test-Ps1StandardOutputRule.ps1
pwsh -NoProfile -File build/Test-Ps1StandardExcelExportRule.ps1
```

Shared analysis lives in `Get-Ps1OutputModel.ps1`. Declaration types, collection
classification, statically named custom types, Excel-switch presence, and
function ownership come from that model. It is cached only within one analysis
object, so declaration and public-output rules see the same facts without
sharing mutable results between files or runs. The scope planner uses the same
type/name parser. The model is part of the custom-cache fingerprint; cache tests
verify that changing it invalidates custom results without discarding built-in
results.

The public-output suite checks the canonical fixture against both output owners.
Class methods and nested helpers cannot introduce declaration/view obligations
for the top-level public function.
