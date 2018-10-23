Param (
    $nodeName = 'SSTC01',
    $ConfigDataPath = ("$PsScriptRoot\configdata.psd1"),
    $DomainJoinCredential = (Get-Credential -Message "Please enter the Domain Join Credential")
)

$Config = Import-PowerShellDataFile -Path $ConfigDataPath

# clean up any pre-existing vm
if (Get-VM -Name $nodeName -ErrorAction SilentlyContinue -OutVariable v) {
    If($v.State -eq 'Running') {
        $v | Stop-VM -Force -Verbose
    }
    Remove-DhcpServerv4Lease -ComputerName $Config.DhcpServer -ScopeId $Config.DhcpScope -ClientId $v.networkadapters[0].MacAddress -Verbose
    $v | Remove-VM -Force -Verbose
    Start-Sleep -Seconds 5
    $comp = Get-AdComputer -Identity $nodeName -ErrorAction SilentlyContinue
    if ($comp) {
        $comp | Remove-ADObject -Recursive -Confirm:$false -Verbose
    }
}

$hvPath = "$($Config.HyperVPath)\$nodeName"
if(Test-Path $hvPath ) {
    remove-item $hvPath -Recurse -Force
}

if (-not(test-path $hvPath)) {
    New-Item -ItemType Directory -Path $hvPath
}
$vmDisk = "$hvPath\$nodeName\$nodeName.vhdx"
copy-item $($Config.TemplateVhd) -Destination $vmDisk -Verbose -force

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
    Save-Module -Name $m -Path $locMdules -Force
}

. $PsScriptRoot\DscMetaConfig.ps1
DscMetaConfig -OutputPath $PSScriptroot\Initialsetup

. $PSScriptRoot\DscSSTC01.ps1
InitialSetup -ConfigurationData $Config -OutputPath $PSScriptroot\Initialsetup -Credential $DomainJoinCredential

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
# remove-item $psscriptroot\InitialSetup -Recurse -force
Get-VM -Name SSTC01 | Start-VM