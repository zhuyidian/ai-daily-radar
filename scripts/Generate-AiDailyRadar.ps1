param(
    [DateTime]$Date = (Get-Date),
    [string]$OutputRoot = ".runs\daily-ai-radar",
    [int]$TopCandidateCount = 30
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

$projectRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
$dateText = $Date.ToString("yyyy-MM-dd")
$runDir = Join-Path $projectRoot (Join-Path $OutputRoot $dateText)

if (-not (Test-Path -LiteralPath $runDir)) {
    throw "Run directory does not exist: $runDir. Run Invoke-AiDailyRadar.ps1 first."
}

$candidatesPath = Join-Path $runDir "candidates.json"
if (-not (Test-Path -LiteralPath $candidatesPath)) {
    throw "Candidates file does not exist: $candidatesPath. Run Collect-AiNewsCandidates.ps1 first."
}

$markdownPath = Join-Path $runDir "daily-ai-radar.md"
$jsonPath = Join-Path $runDir "daily-ai-radar.json"
$generatePromptPath = Join-Path $runDir "generate-prompt.md"
$skillPath = Join-Path $projectRoot "skills\ai-daily-industry-radar\SKILL.md"

$candidateData = Get-Content -LiteralPath $candidatesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$topCandidates = @($candidateData.candidates | Select-Object -First $TopCandidateCount)

$candidateLines = New-Object System.Collections.Generic.List[string]
$index = 1
foreach ($candidate in $topCandidates) {
    $candidateLines.Add((Format-CandidateLine -Candidate $candidate -Index $index))
    $index += 1
}

$promptLines = @(
    "# Generate AI Daily Radar",
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
    "- Date: $dateText",
    "- Window start: $($candidateData.window_start)",
    "- Window end: $($candidateData.window_end)",
    "- Candidate count: $($candidateData.candidate_count)",
    "",
    "Hard requirements:",
    "- Do not copy candidates.json directly into the report.",
    "- Deduplicate stories about the same event.",
    "- Prefer official sources, project pages, release notes, papers, GitHub repositories, regulator pages, or primary company blogs.",
    "- Treat Google News RSS items as discovery leads, not final sources.",
    "- If a candidate is from media/search only, verify it with a primary source or downgrade it to a brief/watchlist item.",
    "- Use absolute dates. Do not write relative dates like today, yesterday, or tomorrow.",
    "- Keep 5-8 top items and 3-8 one-line briefs.",
    "- Do not send to Feishu.",
    "",
    "Top candidates to inspect first:",
    "",
    ($candidateLines -join ([Environment]::NewLine + [Environment]::NewLine)),
    "",
    "After writing the report, ensure daily-ai-radar.json is valid JSON."
)

$prompt = $promptLines -join [Environment]::NewLine
Set-Content -LiteralPath $generatePromptPath -Value $prompt -Encoding UTF8

[PSCustomObject]@{
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
