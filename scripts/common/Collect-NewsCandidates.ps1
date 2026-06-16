param(
    [string]$Topic = "ai",
    [DateTime]$Date = (Get-Date),
    [int]$LookbackHours = 0,
    [int]$MaxItemsPerSource = 0,
    [switch]$NoGoogleNews
)

$ErrorActionPreference = "Stop"

$topicConfig = & (Join-Path $PSScriptRoot "Get-DailyRadarTopic.ps1") -Topic $Topic
if ($LookbackHours -le 0) {
    $LookbackHours = [int]$topicConfig.default_lookback_hours
}
if ($MaxItemsPerSource -le 0) {
    $MaxItemsPerSource = [int]$topicConfig.default_max_items_per_source
}

$collectArgs = @{
    Date = $Date
    LookbackHours = $LookbackHours
    OutputRoot = [string]$topicConfig.RunRoot
    ConfigPath = [string]$topicConfig.collection_config_path
    MaxItemsPerSource = $MaxItemsPerSource
}

if ($NoGoogleNews) {
    $collectArgs.NoGoogleNews = $true
}

& (Join-Path $PSScriptRoot "Collect-RssNewsCandidates.ps1") @collectArgs
