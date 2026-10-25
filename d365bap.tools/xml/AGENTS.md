# Format XML

Do not edit `d365bap.tools.Table.Format.ps1xml` or `d365bap.tools.List.Format.ps1xml`. They are generated and owned by the regen workflow, not by PR authors.

Create and maintain each view in its own file:

- Table: `formats/table/<TypeName>.Table.Format.ps1xml`
- List: `formats/list/<TypeName>.List.Format.ps1xml`

`<TypeName>` is the `PSTypeName` on the object (for example `D365Bap.Tools.UdeEnvironmentPackage`).

After adding or changing a per-type file, push only that file. CI
(`validate-generated`) fails until the regen workflow commits the rebuilt
files back onto the PR branch automatically — usually within minutes, no
action needed.

Local preview only (never commit the result):
`pwsh -NoProfile -File ./build/Merge-FormatPs1Xml.ps1`

The module loads table first (default output), then list (`Format-List`). Do not add views to `FormatsToProcess` in the manifest.
