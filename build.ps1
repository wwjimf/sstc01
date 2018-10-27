#Requires -RunAsAdministrator
#Requires -Version 5.0
#Requires -Modules ActiveDirectory, Hyper-V, DhcpServer, PSDesiredStateConfiguration, PackageManagementProviderResource, ComputerManagementDsc, cChoco


[cmdletbinding()]
param(
    [Parameter()]
    [string[]]
    $Task = 'default',
    
    [Parameter()]
    [String]
    $nodeName = 'SSTC01',

    [Parameter()]
    [String]
    $ConfigDataPath = ("$PsScriptRoot\configdata.psd1"),

    [Parameter()]
    [System.Management.Automation.PSCredential]
    $DomainJoinCredential = (Get-Credential -Message "Please enter the Domain Join Credential"),

    [Parameter()]
    [System.Management.Automation.PSCredential]
    $TeamCityCredential = (Get-Credential -Message "Please enter the TeamCity Service Account Credential")
)

$Modules = @(
    'ActiveDirectory', 
    'Hyper-V', 
    'DhcpServer', 
    'PSDesiredStateConfiguration', 
    'PackageManagementProviderResource', 
    'ComputerManagementDsc', 
    'cChoco'
) | Foreach-Object { 
    if (!(Get-Module -Name $_ -ListAvailable)) { Install-Module -Name $_ -Scope CurrentUser -Force }
}

Invoke-psake -buildFile "$PSScriptRoot\psakeBuild.ps1" -taskList $Task -Verbose:$VerbosePreference