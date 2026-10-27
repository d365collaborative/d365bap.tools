# **d365bap.tools**

A PowerShell module to handle different management tasks related to Business Application Platform, which consist of Microsoft Dynamics 365 Finance & Operations (D365FO) and Dataverse (PowerPlatform)

Read more about D365FO on [learn.microsoft.com](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/fin-ops/).

Read more about Dataverse on [learn.microsoft.com](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/).

Available on PowerShell Gallery:
[d365bap.tools](https://www.powershellgallery.com/packages/d365bap.tools).

## Table of contents
* [Getting started](#getting-started)
* [Getting help](#getting-help)
* [Contributing](#contributing)
* [Dependencies](#dependencies)

## Getting started

It is recommended to use the Core edition of PowerShell (i.e. [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows)). d365bap.tools can be used in the Desktop edition (i.e. Windows PowerShell 5.1), but not all commands will work there.

### Install the latest module
```PowerShell
Install-Module -Name d365bap.tools
```

### Install without administrator privileges
```PowerShell
Install-Module -Name d365bap.tools -Scope CurrentUser
```
### List all available commands / functions

```PowerShell
Get-Command -Module d365bap.tools
```

### Update the module

```PowerShell
Update-Module -name d365bap.tools
```

### Update the module - force

```PowerShell
Update-Module -name d365bap.tools -Force
```

## Preparing the first execution
The module is leveraging the Az.Account module, to obtain all the needed OAuth 2.0 tokens, for the different REST API's spread across the BAP (Business Application Platform) / ODOP (One Dynamics One Platform).

So you will need to sign in with an user account with enough permissions / privileges for the different endpoints. This **must be done prior** running any command from the d365bap.tools module.

```
Login-AzAccount -TenantId abd...
```

Depending on many factors - you will have different sign-in experiences. There are different ways to utilized the Web Browser experience (Device Authentication), which allows for saved credentials to be utilized while authenticating.

```
Login-AzAccount -UseDeviceAuthentication -TenantId abd...
```

### Service Principal
If you have configured a Service Principal, AKA - App Registration, with enough permissions - you can utilize that as well for authentication.

```
$secPass = ConvertTo-SecureString $secretAsText -AsPlainText -Force
$creds = [System.Management.Automation.PSCredential]::new($clientId, $secPass)

Login-AzAccount -TenantId $tenantId -Credential $creds -ServicePrincipal
```

## Getting help

[The wiki](https://github.com/d365collaborative/d365bap.tools/wiki) contains more details about installation and also guides to help you with some common tasks. It also contains documentation for all the module's commands. Expand the wiki's `Pages` control at the top of the content sidebar to view and search the list of command documentation pages.

Another way to learn about the different cmdlets available is to install the tools onto your machine.
You can also visit the **'docs'** folder in this repository (look at the top). Click this link [**docs**](https://github.com/d365collaborative/d365bap.tools/tree/master/docs) to jump straight inside.

Since the project started we have adopted and extended the comment based help inside each cmdlet / function. This means that every single command contains at least one fully working example on how to run it and what to expect from the cmdlet.

**Getting help inside the PowerShell console**

Getting help is as easy as writing **Get-Help CommandName**

```PowerShell
Get-Help Get-BapEnvironment
```

*This will display the available default help.*

Getting the entire help is as easy as writing **Get-Help CommandName -Full**

```PowerShell
Get-Help Get-BapEnvironment -Full
```

*This will display all available help content there is for the cmdlet / function*

Getting all the available examples for a given command is as easy as writing **Get-Help CommandName -Examples**

```PowerShell
Get-Help Get-BapEnvironment -Examples
```

*This will display all the available **examples** for the cmdlet / function.*

We know that when you are learning about new stuff and just want to share your findings with your peers, working with help inside a PowerShell session isn't that great.

### Web based help and examples
We have implemented **platyPS** (https://github.com/PowerShell/platyPS) to generate markdown files for each cmdlet / function available in the module. These files are hosted here on github for you to consume in your web browser and the give you the look and feel of other documentation sites.

The current generated help is available in the [wiki](https://github.com/d365collaborative/d365bap.tools/wiki). The checked-in `docs` directory is a historical snapshot; generated documentation is refreshed and published after changes reach `main`.

## Contributing

Want to contribute to the project? We'd love to have you! Visit our [contributing.md](https://github.com/d365collaborative/d365bap.tools/blob/master/contributing.md) for a jump start.

### Local feedback (optional)

Pull the repo and work as usual — local checks are opt-in. Pull requests run
lint, signature review, and checks selected for the affected files. Broader
repository checks run after merge and must pass before publishing a release.
Documentation-only pull requests skip module tests when no code is affected.

```powershell
# one-time: PowerShell 7.6+, prek, and the lint prerequisite
pip install "prek==0.5.7"
prek install
prek run setup --stage manual

# fast loop: lint changed files + offline behavior tests
prek run
pwsh -NoProfile -File ./build/Test-Behavior.ps1
```

`prek run --all-files --stage manual` lints the whole tree. Do not edit generated
files (`*.Tests.ps1`, `docs/*.md`, consolidated format XML, or
`wiki/Namespaces.md`) in a pull request. CI builds current runtime formats for
validation and generates documentation and test snapshots after merge.

### Accepting public signature changes

`Public signature approval` compares public function declarations against the
PR's merge base. Adding or removing commands or parameters, or changing types,
defaults, aliases, parameter sets, binding attributes, dynamic parameters or
manifest exports requires explicit acceptance. Changes to implementation bodies,
help, formatting and generated tests do not satisfy or trigger acceptance.
This is a declaration review gate, not a complete behavioral compatibility test.

A separate **red check** remains until a maintainer with repository write access
reviews its before/after report and posts this exact text as a new PR comment:

```text
/accept-signature-change
```

The comment applies only to the PR head and base recorded by the visible check.
Wait for that check before commenting. Every new push requires fresh acceptance. Ordinary PR
approval and rerunning workflows do not accept signature changes. Editing or
deleting the acceptance comment revokes it; post a new comment to accept again.
Bot accounts cannot accept. Agents must leave acceptance to the human maintainer;
GitHub cannot distinguish an agent using a person's credentials from that person.

**Repository setup:** merge the workflow onto the default branch, then require
the **Public signature approval** and **PS1 lint (vendored prek hooks, changed
files)** checks in the `main` branch ruleset or protection. Keep the existing
four required validation checks: **Validate Individual Unit Tests** now acts
as the fail-closed aggregate for the fast PR validation. Checks only block
merging when required. Require the PR branch to be up to date with `main` as
well; signature refresh after a base push is best-effort and asynchronous.
Existing PRs need a new push, reopen, or comment to run the new workflow. The
workflow reads tooling from the default branch and parses PR Git blobs without
executing them, so a PR cannot accept itself by editing its tests or gate code.

Gate regression tests: `node --test build/signature-approval.test.cjs`.

## Dependencies

This module depends on other modules. The dependencies are documented in the [dependency graph](https://github.com/d365collaborative/d365bap.tools/network/dependencies) and the Dependencies section of the Package Details of the [package listing](https://www.powershellgallery.com/packages/d365bap.tools) in the PowerShell Gallery.
