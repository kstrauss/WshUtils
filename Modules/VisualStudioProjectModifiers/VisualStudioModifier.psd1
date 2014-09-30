#
# Module manifest for module 'VisualStudioModifier'
#
# Generated by: kstrauss
#
# Generated on: 3/18/2013
#

@{

# Script module or binary module file associated with this manifest.
# RootModule = ''

# Version number of this module.
ModuleVersion = '1.0'

# ID used to uniquely identify this module
GUID = '5635e0df-0dcb-4561-9a9b-fc45069dea73'

# Author of this module
Author = 'kstrauss'

# Company or vendor of this module
CompanyName = 'Realgy'

# Copyright statement for this module
Copyright = '(c) 2013 kstrauss. All rights reserved.'

# Description of the functionality provided by this module
# Description = 'For examing visual studio projects'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module
FunctionsToExport = @("Add-Reference"
	, "Change-Reference"
	, "Get-References"
	, "Remove-Reference"
	, "Get-PostBuildEvent"
	, "Set-PostBuildEvent
	, "Update-NuGetReferencesToUseSolutionDir"
	, "Get-ProjectGuids"
	, "Rejig-SolutionWithMovedProjects")

# Cmdlets to export from this module
CmdletsToExport = ''

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module.
# ModuleList = @()

# List of all files packaged with this module
# FileList = @(VisualStudioProjectModifiers.psm1)

# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

