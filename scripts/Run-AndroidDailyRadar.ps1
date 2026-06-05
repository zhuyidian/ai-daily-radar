param(
    [DateTime]$Date = (Get-Date),
    [int]$LookbackHours = 24,
    [int]$MaxItemsPerSource = 20,
    [int]$TopCandidateCount = 30,
    [switch]$NoGoogleNews,
    [switch]$SkipCollect,
    [switch]$SkipGenerate,
    [switch]$DryRunFeishu,
    [switch]$SendFeishu,
    [switch]$TextOnly
)

$ErrorActionPreference = "Stop"

$runArgs = @{
    Topic = "android"
    Date = $Date
    LookbackHours = $LookbackHours
    MaxItemsPerSource = $MaxItemsPerSource
    TopCandidateCount = $TopCandidateCount
}

foreach ($switchName in @("NoGoogleNews", "SkipCollect", "SkipGenerate", "DryRunFeishu", "SendFeishu", "TextOnly")) {
    if ((Get-Variable -Name $switchName).Value) {
        $runArgs[$switchName] = $true
    }
}

& (Join-Path $PSScriptRoot "Run-DailyRadar.ps1") @runArgs
