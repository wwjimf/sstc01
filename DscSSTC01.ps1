Configuration InitialSetup
{
    param
    (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        $ComputerName = 'localhost',
                
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName PackageManagementProviderResource
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName cChoco

    Node ($Computername)
    {
        Computer JoinDomain
        {
            Name       = 'SSTC01'
            DomainName = 'SolarSystem.Home'
            JoinOU     = 'OU=Servers,OU=BRE,OU=UK,DC=SolarSystem,DC=Home'
            Credential = $Credential # Credential to join to domain
        } 

        Script NugetProvider 
        {
            GetScript = { @{ result = $(Get-PackageProvider -name Nuget -ForceBootstrap -Verbose).Name } }
            SetScript = { Install-PackageProvider -name Nuget -Force -Verbose -ForceBootstrap }
            TestScript = {
                If ($(Get-PackageProvider -name Nuget -ForceBootstrap -Verbose).Name -eq 'Nuget') {
                    $true
                } else {
                    $false
                }
            }
        }

        Group Administrators 
        {
            GroupName        = 'Administrators'
            Ensure           = 'Present'
            MembersToInclude = 'SolarSystem\teamcity'
        }

        cChocoInstaller installChoco
        {
            InstallDir = "C:\choco"
        }

        cChocoPackageInstaller installTeamCity
        {
            Name      = 'TeamCity'
            Ensure    = 'Present'
            Params    = "username=teamcity password=Ictoadp1! domain=SolarSystem"
            Dependson = '[cChocoInstaller]installChoco'
        }

        file TeamCityServerProperties 
        {
            Ensure          = 'Present'
            SourcePath      = 'C:\build\teamcity-startup.properties'
            DestinationPath = 'C:\TeamCity\conf\teamcity-startup.properties'
            Dependson = '[cChocoPackageInstaller]installTeamCity'
        }
    }
}