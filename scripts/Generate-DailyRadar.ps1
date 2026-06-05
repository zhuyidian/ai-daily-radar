param(
    [string]$Topic = "ai",
    [DateTime]$Date = (Get-Date),
    [int]$TopCandidateCount = 0
)

$ErrorActionPreference = "Stop"

function Format-CandidateLine {
    param(
        [object]$Candidate,
        [int]$Index
    )

    $published = if ($Candidate.published_at) { [string]$Candidate.published_at } else { "unknown" }
    $score = if ($null -ne $Candidate.candidate_score) { [string]$Candidate.candidate_score } else { "unknown" }
    $source = if ($Candidate.source_name) { [string]$Candidate.source_name } else { "unknown source" }
    $title = if ($Candidate.title) { [string]$Candidate.title } else { "Untitled" }
    $url = if ($Candidate.url) { [string]$Candidate.url } else { "" }

    return @(
        "$Index. $title",
        "   - Source: $source",
        "   - Published: $published",
        "   - Candidate score: $score",
        "   - URL: $url"
    ) -join [Environment]::NewLine
}

$topicConfig = & (Join-Path $PSScriptRoot "Get-DailyRadarTopic.ps1") -Topic $Topic
if ($TopCandidateCount -le 0) {
    $TopCandidateCount = [int]$topicConfig.default_top_candidate_count
}

$projectRoot = [string]$topicConfig.ProjectRoot
$dateText = $Date.ToString("yyyy-MM-dd")
$runDir = Join-Path $projectRoot (Join-Path ([string]$topicConfig.RunRoot) $dateText)

if (-not (Test-Path -LiteralPath $runDir)) {
    throw "Run directory does not exist: $runDir. Run Invoke-DailyRadar.ps1 first."
}

$candidatesPath = Join-Path $runDir "candidates.json"
if (-not (Test-Path -LiteralPath $candidatesPath)) {
    throw "Candidates file does not exist: $candidatesPath. Run Collect-NewsCandidates.ps1 first."
}

$markdownPath = Join-Path $runDir ([string]$topicConfig.output_markdown_name)
$jsonPath = Join-Path $runDir ([string]$topicConfig.output_json_name)
$generatePromptPath = Join-Path $runDir "generate-prompt.md"
$skillPath = [string]$topicConfig.SkillFullPath

$candidateData = Get-Content -LiteralPath $candidatesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$topCandidates = @($candidateData.candidates | Select-Object -First $TopCandidateCount)

$candidateLines = New-Object System.Collections.Generic.List[string]
$index = 1
foreach ($candidate in $topCandidates) {
    $candidateLines.Add((Format-CandidateLine -Candidate $candidate -Index $index))
    $index += 1
}

$requirements = @($topicConfig.report_requirements | ForEach-Object { "- $_" })

$promptLines = @(
    "# $($topicConfig.prompt_title)",
    "",
    "Read the candidate file:",
    $candidatesPath,
    "",
    "Follow the skill:",
    $skillPath,
    "",
    "Write the final report in Chinese.",
    "",
    "Output files:",
    "- Markdown: $markdownPath",
    "- JSON: $jsonPath",
    "",
    "Reporting window:",
    "- Topic: $($topicConfig.id)",
    "- Date: $dateText",
    "- Window start: $($candidateData.window_start)",
    "- Window end: $($candidateData.window_end)",
    "- Candidate count: $($candidateData.candidate_count)",
    "",
    "Focus areas:",
    (@($topicConfig.focus_areas | ForEach-Object { "- $_" }) -join [Environment]::NewLine),
    "",
    "Hard requirements:",
    ($requirements -join [Environment]::NewLine),
    "",
    "Top candidates to inspect first:",
    "",
    ($candidateLines -join ([Environment]::NewLine + [Environment]::NewLine)),
    "",
    "After writing the report, ensure the JSON file is valid JSON."
)

$prompt = $promptLines -join [Environment]::NewLine
Set-Content -LiteralPath $generatePromptPath -Value $prompt -Encoding UTF8

[PSCustomObject]@{
    Topic = $topicConfig.id
    Date = $dateText
    RunDir = $runDir
    CandidatesPath = $candidatesPath
    CandidateCount = $candidateData.candidate_count
    TopCandidateCount = $topCandidates.Count
    GeneratePromptPath = $generatePromptPath
    MarkdownPath = $markdownPath
    JsonPath = $jsonPath
    NextStep = "Ask Codex: Read generate-prompt.md and generate the report, but do not send to Feishu yet."
} | ConvertTo-Json -Depth 6
