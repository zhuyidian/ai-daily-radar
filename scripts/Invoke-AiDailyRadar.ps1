param(
    [DateTime]$Date = (Get-Date),
    [int]$LookbackHours = 24,
    [string]$OutputRoot = ".runs\daily-ai-radar"
)

$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$dateText = $Date.ToString("yyyy-MM-dd")
$runDir = Join-Path $projectRoot (Join-Path $OutputRoot $dateText)

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$markdownPath = Join-Path $runDir "daily-ai-radar.md"
$jsonPath = Join-Path $runDir "daily-ai-radar.json"
$promptPath = Join-Path $runDir "run-prompt.md"
$sourcesTarget = Join-Path $runDir "sources.json"

$templatePath = Join-Path $projectRoot "templates\daily-ai-radar.md"
$sourcesPath = Join-Path $projectRoot "config\sources.json"
$automationPromptPath = Join-Path $projectRoot "config\automation-prompt.md"

if (-not (Test-Path -LiteralPath $markdownPath)) {
    Copy-Item -LiteralPath $templatePath -Destination $markdownPath
}

Copy-Item -LiteralPath $sourcesPath -Destination $sourcesTarget -Force

$windowEnd = $Date
$windowStart = $Date.AddHours(-1 * $LookbackHours)
$automationPrompt = Get-Content -LiteralPath $automationPromptPath -Raw -Encoding UTF8

$runPromptLines = @(
    $automationPrompt.TrimEnd(),
    "",
    "Run parameters:",
    "",
    "- Date: $dateText",
    "- Window start: $($windowStart.ToString("yyyy-MM-dd HH:mm:ss zzz"))",
    "- Window end: $($windowEnd.ToString("yyyy-MM-dd HH:mm:ss zzz"))",
    "- Markdown output: $markdownPath",
    "- JSON output: $jsonPath",
    "- Sources config: $sourcesTarget",
    "",
    "Search and verify the information first, then overwrite the Markdown and JSON output files."
)

$runPrompt = $runPromptLines -join [Environment]::NewLine

Set-Content -LiteralPath $promptPath -Value $runPrompt -Encoding UTF8

[PSCustomObject]@{
    Date = $dateText
    RunDir = $runDir
    MarkdownPath = $markdownPath
    JsonPath = $jsonPath
    PromptPath = $promptPath
    SourcesPath = $sourcesTarget
} | ConvertTo-Json -Depth 4
