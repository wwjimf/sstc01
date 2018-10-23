[DSCLocalConfigurationManager()]
configuration DscMetaConfig
{
    Node localhost
    {
        Settings
        {
            RefreshMode = 'Push'
            ConfigurationModeFrequencyMins = 15
            RefreshFrequencyMins = 30
            ActionAfterReboot = 'ContinueConfiguration'
            RebootNodeIfNeeded = $true
        }
    }
}