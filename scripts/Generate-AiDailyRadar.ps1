param(
    [DateTime]$Date = (Get-Date),
    [string]$OutputRoot = "",
    [int]$TopCandidateCount = 30
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "Generate-DailyRadar.ps1") `
    -Topic "ai" `
    -Date $Date `
    -TopCandidateCount $TopCandidateCount
