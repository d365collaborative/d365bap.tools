# Format XML

Do not edit `d365bap.tools.Table.Format.ps1xml` or `d365bap.tools.List.Format.ps1xml`. CI generates them from the per-view sources.

Create and maintain each view in its own file:

- Table: `formats/table/<TypeName>.Table.Format.ps1xml`
- List: `formats/list/<TypeName>.List.Format.ps1xml`

`<TypeName>` is the `PSTypeName` on the object (for example `D365Bap.Tools.UdeEnvironmentPackage`).

After adding or changing a per-type file, push only that file. The PR compiled
import check generates both consolidated formats in staging and validates
them. Release packaging generates them again after merge.

Local preview only (never commit the result):
`pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1`

The module loads table first (default output), then list (`Format-List`). Do not add views to `FormatsToProcess` in the manifest.
