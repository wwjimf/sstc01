# Pester validation testsget-ps1

Param (
    $nodeName = 'SSTC01'
)

$Config = Import-PowerShellDataFile -Path $PSScriptRoot\configdata.psd1
$node = $config.AllNodes | Where NodeName -eq $nodeName

    
Describe "The VM -- $NodeName" {
        
    $vm = get-vm -name $NodeName -ErrorAction SilentlyContinue
        
    It 'Is created' {
        $vm | should -Not -BeNullOrEmpty
    }

    It 'Is Running' {
        $vm.state | Should -Be 'Running'
    }

    It 'Has a valid DHCP Lease' {
        $lease = get-dhcpserverv4lease -computername $config.DhcpServer -ScopeId $($config.DhcpScope) -clientId $vm.networkadapters[0].MacAddress
        $lease.AddressState | Should -Be 'Active'
    }

    It 'Has a valid AD computer account' {
        $comp = Get-ADCOmputer -Identity $nodeName
        $comp.Enabled | Should -Be $True
    }

    It 'The teamcity service is running' {
        $svc = get-service  -name teamcity -ComputerName $nodeName
        $svc.status | Should -Be 'Running'
    }
}
