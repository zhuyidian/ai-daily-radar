param(
    [DateTime]$Date = (Get-Date),
    [int]$LookbackHours = 24,
    [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$invokeArgs = @{
    Topic = "ai"
    Date = $Date
    LookbackHours = $LookbackHours
}

& (Join-Path $PSScriptRoot "Invoke-DailyRadar.ps1") @invokeArgs
