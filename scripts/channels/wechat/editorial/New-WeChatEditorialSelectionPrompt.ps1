param(
    [string]$Topic = "ai",
    [DateTime]$Date = (Get-Date),
    [int]$LookbackDays = 0
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Editorial.Common.ps1")

$topicConfig = Get-EditorialTopic -Topic $Topic
$editorialConfig = Read-EditorialConfig -TopicConfig $topicConfig
$config = $editorialConfig.Value
if ($LookbackDays -le 0) {
    $LookbackDays = [int]$config.lookback_days
}
if ($LookbackDays -le 0) {
    throw "LookbackDays must be greater than zero."
}

$paths = Get-EditorialOutputPaths -TopicConfig $topicConfig -Date $Date
$reports = New-Object System.Collections.Generic.List[object]
for ($offset = 0; $offset -lt $LookbackDays; $offset++) {
    $reportDate = $Date.Date.AddDays(-$offset)
    $commonDir = Join-Path (Join-Path (Get-EditorialProjectRoot) (Join-Path ([string]$topicConfig.RunRoot) $reportDate.ToString("yyyy-MM-dd"))) "common"
    $jsonPath = Join-Path $commonDir ([string]$topicConfig.output_json_name)
    if (-not (Test-Path -LiteralPath $jsonPath)) {
        continue
    }
    $markdownPath = Join-Path $commonDir ([string]$topicConfig.output_markdown_name)
    $report = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $reports.Add([PSCustomObject]@{
        date = $reportDate.ToString("yyyy-MM-dd")
        json_path = (Resolve-Path -LiteralPath $jsonPath).Path
        markdown_path = if (Test-Path -LiteralPath $markdownPath) { (Resolve-Path -LiteralPath $markdownPath).Path } else { $null }
        top_item_count = @($report.top_items).Count
        brief_count = @($report.briefs).Count
    })
}

if ($reports.Count -eq 0) {
    throw "No report JSON files were found in the last $LookbackDays day(s). Generate at least one daily report first."
}

$projectRoot = Get-EditorialProjectRoot
$skillPath = Join-Path $projectRoot "skills\wechat-editorial-writer\SKILL.md"
$manifest = [PSCustomObject]@{
    topic = [string]$topicConfig.id
    date = $Date.ToString("yyyy-MM-dd")
    generated_at = ([DateTimeOffset]::Now).UtcDateTime.ToString("o")
    lookback_days = $LookbackDays
    editorial_config_path = $editorialConfig.Path
    skill_path = $skillPath
    reports = @($reports | ForEach-Object { $_ })
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $paths.SourceManifestPath -Encoding UTF8

$reportPaths = @($reports | ForEach-Object { "- $($_.date): $($_.json_path)" }) -join [Environment]::NewLine
$readers = @($config.target_readers | ForEach-Object { "- $_" }) -join [Environment]::NewLine
$articleTypes = @($config.article_types.PSObject.Properties | ForEach-Object {
    "- $($_.Name): $($_.Value.label), $($_.Value.min_chars)-$($_.Value.max_chars) Chinese characters"
}) -join [Environment]::NewLine

$prompt = @"
# Select a WeChat Editorial Topic

Read the project skill completely:
$skillPath

Read the source manifest:
$($paths.SourceManifestPath)

Read every report JSON listed below:
$reportPaths

Select one topic for a high-quality Chinese WeChat Official Account article. This is not a daily digest.

Target readers:
$readers

Available article types:
$articleTypes

Selection rules:
- Propose exactly 3 candidate angles and score each out of 100.
- Score reader relevance 20, novelty 15, consequence 15, tension or counter-intuition 15, source strength 15, independent judgment 10, and title/visual potential 10.
- The chosen angle needs at least $($config.min_related_items) related evidence items and may use at most $($config.max_selected_items).
- Set publish=false when the best score is below $($config.min_topic_score), the thesis is vague, or the evidence does not support a feature article.
- Select one article_type from the configured keys.
- News items are evidence, not parallel sections. Explicitly exclude unrelated high-scoring items.
- Do not write the article in this step.

Write valid JSON to:
$($paths.DecisionPath)

Required schema:
~~~json
{
  "publish": true,
  "reason": "",
  "topic_score": 0,
  "article_type": "$($config.default_article_type)",
  "thesis": "one clear Chinese sentence",
  "target_readers": [],
  "reader_question": "",
  "why_now": "",
  "candidate_angles": [
    {
      "angle": "",
      "score": 0,
      "strength": "",
      "weakness": ""
    }
  ],
  "selected_items": [
    {
      "report_date": "YYYY-MM-DD",
      "title": "exact title from a report",
      "role": "core evidence or supporting evidence",
      "source_url": "",
      "why_selected": ""
    }
  ],
  "excluded_items": [
    {
      "title": "",
      "reason": ""
    }
  ],
  "working_title_angles": []
}
~~~

Keep source titles and URLs exact. Finish after writing the decision file.
"@
$prompt | Set-Content -LiteralPath $paths.SelectionPromptPath -Encoding UTF8

[PSCustomObject]@{
    Topic = [string]$topicConfig.id
    Date = $Date.ToString("yyyy-MM-dd")
    ReportCount = $reports.Count
    OutputDir = $paths.OutputDir
    SourceManifestPath = $paths.SourceManifestPath
    SelectionPromptPath = $paths.SelectionPromptPath
    DecisionPath = $paths.DecisionPath
    NextStep = "Ask Codex to read editorial-selection-prompt.md and write editorial-decision.json."
} | ConvertTo-Json -Depth 6
