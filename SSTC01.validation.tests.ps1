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

    $lease = get-dhcpserverv4lease -computername $config.DhcpServer -ScopeId $($config.DhcpScope) -clientId $vm.networkadapters[0].MacAddress
    
    It 'Has 1 DHCP lease' {
        $lease.IpAddress.Count | Should -Be 1
    }
    
    It 'Has a valid DHCP Lease' {
        $lease.AddressState | Should -Be 'Active'
    }

    $dns = Resolve-DnsName -Name $NodeName -Type A
    It 'Has exactly 1 DNS A record' {
        $dns.count | Should -Be 1
    }

    $leaseIP = $lease.IPAddress.IPAddressToString
    $DnsIp = $dns.ipaddress

    It 'DNS A record IP address matches DHCP lease' {
        $DnsIp | Should -Be $leaseIP
    }

    It 'Has a valid AD computer account' {
        $comp = Get-ADCOmputer -Identity $nodeName
        $comp.Enabled | Should -Be $True
    }

    It 'WSMAN should be accepting connections' {
        $result = Test-Connection -ComputerName $nodeName -Protocol WSMan -Quiet
        $result | should -Be $true
    }

    It 'The DSC Configuration Status cmdlet should not throw' {
        $csess = New-CimSession -ComputerName $nodeName
        { Get-DscConfigurationStatus -CimSession $csess } | Should -Not -Throw
        $csess | remove-cimsession
    }

    $svc = get-service  -name teamcity -ComputerName $nodeName -ErrorAction SilentlyContinue
    It 'The teamcity service should exist' {
        $svc | Should -Not -BeNullOrEmpty
    }

    It 'The teamcity service is running' {
        if($svc.Status -eq 'Stopped') {
            invoke-command -Computername $NodeName -scriptblock { Start-Service -Name teamcity }
        }
        $svc = get-service -computername $NodeName -Name TeamCity
        $svc.status | Should -Be 'Running'
    }

    It 'The webserver returns status 200' {
        $result = Invoke-WebRequest -Uri http://sstc01.solarsystem.home:8111
        $result.StatusCode | Should -Be 200

    }
}
