
Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -PercentComplete 1
$i = 0
$complete = $false
While($complete -eq $false) {
    $i++
    $pct = $i * 10
    if($pct -gt 100) {
        $pct = 10
    }
    Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -Status "Waiting $i test iterations..." -PercentComplete $pct
    $results = invoke-pester -Script $PSScriptRoot\SSTC01.validation.tests.ps1 -Show None -PassThru
    If ($results.FailedCount -eq 0) {
        Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -Status "Configuration Complete" -PercentComplete 100
        $complete = $true
        Write-Progress -id 1 -Activity "Waiting for vm build and config to complete" -Completed
        $results
    } else {
        Clear-Host
        $results.TestResult | where Result -eq 'Failed'
        start-sleep -seconds 5
    }   
}

