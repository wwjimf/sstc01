#Requires -RunAsAdministrator
#Requires -Version 5.0
#Requires -Modules ActiveDirectory, Hyper-V, DhcpServer, PSDesiredStateConfiguration, PackageManagementProviderResource, ComputerManagementDsc, cChoco

Param (
    $nodeName = 'SSTC01',
    $ConfigDataPath = ("$PsScriptRoot\configdata.psd1"),
    $DomainJoinCredential = (Get-Credential -Message "Please enter the Domain Join Credential"),
    $TeamCityCredential = (Get-Credential -Message "Please enter the TeamCity Service Account Credential")
)

$Config = Import-PowerShellDataFile -Path $ConfigDataPath

# clean up any pre-existing vm
if (Get-VM -Name $nodeName -ErrorAction SilentlyContinue -OutVariable v) {
    
    ## Function CleanUpVM
    If($v.State -eq 'Running') {
        $v | Stop-VM -Force -Verbose
    }
    if (get-dhcpserverv4lease -computername $Config.DhcpServer -ScopeId $Config.DhcpScope -clientId $v.NetworkAdapters[0].MacAddress) {
        Remove-DhcpServerv4Lease -ComputerName $Config.DhcpServer -ScopeId $Config.DhcpScope -ClientId $v.networkadapters[0].MacAddress -Verbose
    }

    If ( Get-DnsServerResourceRecord -Name $nodeName -ComputerName $Config.DnsServer -ZoneName $Config.DnsZone) {
        Remove-DnsServerResourceRecord -computername $Config.DnsServer -ZoneName $Config.DnsZone -Name $nodeName -RRType A -Force -Confirm:$false -Verbose
        Remove-DnsServerResourceRecord -computername $Config.DnsServer -ZoneName $Config.DnsZone -Name $nodeName -RRType AAAA -Force -Confirm:$false -Verbose
    }    
    
    $v | Remove-VM -Force -Verbose
    
    Start-Sleep -Seconds 5

    $comp = Get-AdComputer -Identity $nodeName -ErrorAction SilentlyContinue
    if ($comp) {
        $comp | Remove-ADObject -Recursive -Confirm:$false -Verbose
    }
}

## Function CreateVirtualDiskFromTemplate
$hvPath = "$($Config.HyperVPath)\$nodeName"
if(Test-Path $hvPath ) {
    remove-item $hvPath -Recurse -Force
}

if (-not(test-path $hvPath)) {
    New-Item -ItemType Directory -Path $hvPath
}
$vmDisk = "$hvPath\$nodeName.vhdx"
copy-item $($Config.TemplateVhd) -Destination $vmDisk -Verbose -force

## Function InitialiseModules
$modules = @('PackageManagementProviderResource', 'ComputerManagementDsc', 'cChoco')
foreach($m in $modules) {
    If(-not (get-module -Name $m -ListAvailable)) {
        Install-Module -Name $m -force
    }
}

$locModules = "$PSScriptRoot\Modules"
If(-not(Test-Path $locModules)) {
    New-Item $locModules -ItemType Directory -Force
}

foreach($m in $Modules) {
    Save-Module -Name $m -Path $locModules -Force
}

## Function Compile MetaMof
$locInitialSetup = "$PSScriptroot\Initialsetup"
. $PsScriptRoot\DscMetaConfig.ps1
DscMetaConfig -OutputPath $locInitialSetup

## Function Compile Mof
. $PSScriptRoot\DscSSTC01.ps1
InitialSetup -ConfigurationData $Config -OutputPath $locInitialSetup -Credential $DomainJoinCredential -TeamCityCredential $TeamCityCredential

## Function CreateVM
$vmProps = @{
    Name = $nodeName
    Path = $hvPath
    MemoryStartUpBytes = $Config.VmRam
    SwitchName = $Config.VmSwitch
    Generation =  $Config.VmGen
    VHDPath = $vmDisk
}
New-VM @VmProps
Set-VM -Name SSTC01 -ProcessorCount 2 -DynamicMemory

## Function InjectVmFiles
$mount = Mount-vhd -Path $vmDisk -passthru

$drv = ($mount | get-disk | Get-Partition | Get-Volume | Where DriveLetter).DriveLetter

$remRoot        = "$drv`:"
$remUnattend    = "$remRoot\Windows\Panther"
$remMetaMof     = "$remRoot\Windows\system32\Configuration\MetaConfig.mof"
$remMof         = "$remRoot\Windows\system32\Configuration\Pending.mof"
$remModules     = "$remRoot\Program Files\WindowsPowershell\Modules"
$remProgramData = "$remRoot\ProgramData"

$locUnattend    = "$PSScriptRoot\unattend.xml"
$locMetaMof     = "$PsScriptRoot\InitialSetup\localhost.meta.mof"
$locMof         = "$PsScriptRoot\InitialSetup\localhost.mof"

$locJetBrains   = "$PsscriptRoot\ProgramData\JetBrains"
$locBuild       = "$PsScriptRoot\Build"

Copy-Item $locUnattend -Destination $remUnattend -Verbose
Copy-Item $locMetaMof -Destination $remMetaMof -Verbose
Copy-Item $locMof -Destination $remMof -Verbose

Get-ChildItem $locModules | foreach-Object{ Copy-Item $_.FullName -destination $remModules -Recurse -force -verbose }

Copy-item $locJetBrains -Destination $RemProgramData -Recurse -Force -verbose
Copy-Item $locBuild -Destination "$remRoot\" -recurse -force

Dismount-VHD -Path $vmDisk

remove-item $psscriptroot\InitialSetup -Recurse -force

Get-VM -Name $nodeName | Start-VM

# Function WaitFor
Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -PercentComplete -1
$i = 0
$complete = $false
While($complete -eq $false) {
    $i++
    Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -Status "Waiting $i test iterations..." -PercentComplete -1
    $results = invoke-pester -Script $PSScriptRoot\SSTC01.validation.tests.ps1 -Show None -PassThru
    If ($results.FailedCount -eq 0) {
        Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -Status "Configuration Complete" -PercentComplete -1
        $complete = $true
        Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -Completed
        $results
    } else {
        Clear-Host
        $results.TestResult | where Result -eq 'Failed'
        $sleep = 30
        Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -Status "Sleeping for $sleep seconds" -PercentComplete -1
        start-sleep -seconds $sleep
    }   
}