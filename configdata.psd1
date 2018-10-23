@{   
    AllNodes = @(
        @{     
            NodeName = "LocalHost" 
            # Allows credential to be saved in plain-text in the the *.mof instance document.                             
            PSDscAllowPlainTextPassword = $true 
            PSDscAllowDomainUser = $true
        },             
        @{     
            NodeName = "SSTC01" 
            # Allows credential to be saved in plain-text in the the *.mof instance document.                             
            PSDscAllowPlainTextPassword = $true 
            PSDscAllowDomainUser = $true
        } 
    )
    HyperVHost  = 'SSAPP03'
    HyperVPath  = 'D:\Hyper-V\VHD'
    TemplateVhd = 'D:\Templates\1803_template.vhdx'
    VmRam       = 1GB
    VmSwitch    = "SSAPP03-Switch-01"
    VmGen       = 2
    DhcpServer  = "SSDC03"
    DhcpScope   = "192.168.1.0"
    DnsServer   = "SSDC03"
    DnsZone     = "SolarSystem.Home"
} 