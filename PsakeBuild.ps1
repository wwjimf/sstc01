properties {
    $script = "$PSScriptRoot\Create-Vm.ps1"
}

task default -depends Analyze, Test

task Analyze {
    Write-Host "Running Script Analyser"
    $saResults = Invoke-ScriptAnalyzer -Path $script -Severity @('Error', 'Warning') -Recurse -Verbose:$false
    if ($saResults) {
        $saResults | Format-Table  
        Write-Error -Message 'One or more Script Analyzer errors/warnings where found. Build cannot continue!'        
    }
    Write-Host "Static analysis has no issues"
}

task Test {
    $testResults = Invoke-Pester -Path $PSScriptRoot\SSTC01.validation.tests.ps1 -PassThru
    if ($testResults.FailedCount -gt 0) {
        $testResults | Format-List
        Write-Error -Message 'One or more Pester tests failed. Build cannot continue!'
    }
}

