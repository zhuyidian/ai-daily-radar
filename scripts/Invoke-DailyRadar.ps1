param(
    [string]$Topic = "ai",
    [DateTime]$Date = (Get-Date),
    [int]$LookbackHours = 0
)

$ErrorActionPreference = "Stop"

$topicConfig = & (Join-Path $PSScriptRoot "Get-DailyRadarTopic.ps1") -Topic $Topic
if ($LookbackHours -le 0) {
    $LookbackHours = [int]$topicConfig.default_lookback_hours
}

$projectRoot = [string]$topicConfig.ProjectRoot
$dateText = $Date.ToString("yyyy-MM-dd")
$runDir = Join-Path $projectRoot (Join-Path ([string]$topicConfig.RunRoot) $dateText)

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$markdownPath = Join-Path $runDir ([string]$topicConfig.output_markdown_name)
$jsonPath = Join-Path $runDir ([string]$topicConfig.output_json_name)
$promptPath = Join-Path $runDir "run-prompt.md"
$sourcesTarget = Join-Path $runDir "sources.json"

if (-not (Test-Path -LiteralPath $markdownPath)) {
    Copy-Item -LiteralPath ([string]$topicConfig.TemplateFullPath) -Destination $markdownPath
}

if (Test-Path -LiteralPath ([string]$topicConfig.SourcesFullPath)) {
    Copy-Item -LiteralPath ([string]$topicConfig.SourcesFullPath) -Destination $sourcesTarget -Force
}

$windowEnd = $Date
$windowStart = $Date.AddHours(-1 * $LookbackHours)
$automationPrompt = Get-Content -LiteralPath ([string]$topicConfig.AutomationPromptFullPath) -Raw -Encoding UTF8

$runPromptLines = @(
    $automationPrompt.TrimEnd(),
    "",
    "Run parameters:",
    "",
    "- Topic: $($topicConfig.id)",
    "- Date: $dateText",
    "- Window start: $($windowStart.ToString("yyyy-MM-dd HH:mm:ss zzz"))",
    "- Window end: $($windowEnd.ToString("yyyy-MM-dd HH:mm:ss zzz"))",
    "- Markdown output: $markdownPath",
    "- JSON output: $jsonPath",
    "- Sources config: $sourcesTarget",
    "- Topic config: $($topicConfig.TopicConfigPath)",
    "",
    "Search and verify the information first, then overwrite the Markdown and JSON output files."
)

$runPrompt = $runPromptLines -join [Environment]::NewLine
Set-Content -LiteralPath $promptPath -Value $runPrompt -Encoding UTF8

[PSCustomObject]@{
    Topic = $topicConfig.id
    Date = $dateText
    RunDir = $runDir
    MarkdownPath = $markdownPath
    JsonPath = $jsonPath
    PromptPath = $promptPath
    SourcesPath = $sourcesTarget
    TopicConfigPath = $topicConfig.TopicConfigPath
} | ConvertTo-Json -Depth 5
