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

Depending on which PowerShell console (v5 / v7+) - you will have different sign-in experiences. There are different ways to utilized the Web Browser experience (Device Authentication), which allows for saved credentials to be utilized while authenticating.

```
Login-AzAccount -UseDeviceAuthentication -TenantId abd...
```

## Learn interactively

We have implemented a **Jupyter Notebook** to help you learn interactively about the different cmdlets / functions available in the module. The notebook is located inside the **'notebooks'** folder in this repository. Click this link [**notebooks**](/learning/notebooks/get-started.ipynb) to jump straight inside.

While the notebook is already helpful in itself, its interactive nature will help you learn on another level. To do that, open the notebook in Visual Studio Code with the [Polyglot](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.dotnet-interactive-vscode) extension installed.

The repository also contains a [devcontainer](.devcontainer/devcontainer.json) that has everything installed to run the notebook. The easiest way to get started is to use GitHub Codespaces. Click the button below to start a new Codespace with the repository.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/d365collaborative/d365bap.tools)

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

The generated help markdown files are located inside the **'docs'** folder in this repository. Click this [link](https://github.com/d365collaborative/d365bap.tools/tree/master/docs) to jump straight inside.

They are also available in the [wiki](https://github.com/d365collaborative/d365bap.tools/wiki) in the list of pages.

## Contributing

Want to contribute to the project? We'd love to have you! Visit our [contributing.md](https://github.com/d365collaborative/d365bap.tools/blob/master/contributing.md) for a jump start.

## Dependencies

This module depends on other modules. The dependencies are documented in the [dependency graph](https://github.com/d365collaborative/d365bap.tools/network/dependencies) and the Dependencies section of the Package Details of the [package listing](https://www.powershellgallery.com/packages/d365bap.tools) in the PowerShell Gallery.