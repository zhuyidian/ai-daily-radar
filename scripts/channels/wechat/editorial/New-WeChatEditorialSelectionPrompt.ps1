param(
    [string]$Topic = "ai",
    [DateTime]$Date = (Get-Date),
    [int]$LookbackDays = 0
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Editorial.Common.ps1")

function Test-TopicCategoryExists {
    param(
        [object[]]$Categories,
        [string]$Key
    )

    return $null -ne (@($Categories) | Where-Object { [string]$_.key -eq $Key } | Select-Object -First 1)
}

function Resolve-LegacyTopicCategory {
    param(
        [object]$Decision,
        [object[]]$Categories
    )

    if ($Decision.topic_category) {
        return [string]$Decision.topic_category
    }

    $selectedText = @($Decision.selected_items | ForEach-Object { [string]$_.title }) -join " "
    $text = @(
        [string]$Decision.thesis,
        [string]$Decision.reader_question,
        $selectedText
    ) -join " "

    $rules = @(
        @{ key = "agent_workflow"; pattern = "Agent|agent|Codex|Claude Code|Copilot|Interactions API|MCP|Slack" },
        @{ key = "ai_infrastructure"; pattern = "GPU|NVIDIA|Broadcom|Micron|Vera|HPC|inference|chip|data center|memory" },
        @{ key = "policy_safety"; pattern = "Five Eyes|AISI|export|regulation|governance|safety|policy|security|Control Roadmap" },
        @{ key = "open_source_model"; pattern = "MIT|Hugging Face|Llama|Qwen|DeepSeek|GLM|open-weight|open source" },
        @{ key = "china_ai"; pattern = "Alibaba|Zhipu|Z\.ai|GLM|Qwen|DeepSeek|LatePost" },
        @{ key = "business_funding"; pattern = "funding|acquisition|merger|revenue|IPO|partnership|Salesforce|KPMG|TCS" },
        @{ key = "product_app"; pattern = "ChatGPT|Slack|Figma|video|image|audio|voice|Notion|Perplexity|Product Hunt" },
        @{ key = "model_release"; pattern = "Claude|GPT|Gemini|OpenAI|Anthropic|DeepMind|benchmark|model" },
        @{ key = "release_tools"; pattern = "Android Studio|Gradle|AGP|Kotlin|Compose|release|tool" },
        @{ key = "platform_api"; pattern = "Android|API|compatibility|platform" },
        @{ key = "play_policy"; pattern = "Google Play|Play Console|review|policy" },
        @{ key = "performance_quality"; pattern = "performance|stability|test|quality|crash|ANR" },
        @{ key = "security_privacy"; pattern = "security|privacy|permission|supply chain" },
        @{ key = "architecture_practice"; pattern = "architecture|migration|engineering practice" },
        @{ key = "device_ecosystem"; pattern = "foldable|XR|car|Auto|Wear|device" }
    )

    foreach ($rule in $rules) {
        if ((Test-TopicCategoryExists -Categories $Categories -Key $rule.key) -and $text -match $rule.pattern) {
            return [string]$rule.key
        }
    }

    return "legacy_uncategorized"
}

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
$projectRoot = Get-EditorialProjectRoot
$configuredTopicCategories = @($config.topic_categories)
$historyLookbackDays = if ($config.history_lookback_days) { [int]$config.history_lookback_days } else { 30 }
$historyMaxItems = if ($config.history_max_items) { [int]$config.history_max_items } else { 8 }
$similarTopicScoreCap = if ($config.similar_topic_score_cap) { [int]$config.similar_topic_score_cap } else { 74 }
$reports = New-Object System.Collections.Generic.List[object]
for ($offset = 0; $offset -lt $LookbackDays; $offset++) {
    $reportDate = $Date.Date.AddDays(-$offset)
    $commonDir = Join-Path (Join-Path $projectRoot (Join-Path ([string]$topicConfig.RunRoot) $reportDate.ToString("yyyy-MM-dd"))) "common"
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

$recentDecisions = New-Object System.Collections.Generic.List[object]
for ($offset = 1; $offset -le $historyLookbackDays; $offset++) {
    if ($recentDecisions.Count -ge $historyMaxItems) {
        break
    }
    $historyDate = $Date.Date.AddDays(-$offset)
    $decisionPath = Join-Path (Join-Path (Join-Path (Join-Path (Join-Path $projectRoot ([string]$topicConfig.RunRoot)) $historyDate.ToString("yyyy-MM-dd")) "channels") "wechat") "editorial\editorial-decision.json"
    if (-not (Test-Path -LiteralPath $decisionPath)) {
        continue
    }
    $decision = Get-Content -LiteralPath $decisionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $decision.publish -and -not [bool]$decision.publish) {
        continue
    }
    $recentDecisions.Add([PSCustomObject]@{
        date = $historyDate.ToString("yyyy-MM-dd")
        decision_path = (Resolve-Path -LiteralPath $decisionPath).Path
        topic_category = Resolve-LegacyTopicCategory -Decision $decision -Categories $configuredTopicCategories
        article_type = if ($decision.article_type) { [string]$decision.article_type } else { "" }
        topic_score = if ($decision.topic_score) { [int]$decision.topic_score } else { 0 }
        thesis = if ($decision.thesis) { [string]$decision.thesis } else { "" }
        reader_question = if ($decision.reader_question) { [string]$decision.reader_question } else { "" }
        selected_titles = @($decision.selected_items | ForEach-Object { [string]$_.title })
    })
}

$skillPath = Join-Path $projectRoot "skills\wechat-editorial-writer\SKILL.md"
$manifest = [PSCustomObject]@{
    topic = [string]$topicConfig.id
    date = $Date.ToString("yyyy-MM-dd")
    generated_at = ([DateTimeOffset]::Now).UtcDateTime.ToString("o")
    lookback_days = $LookbackDays
    history_lookback_days = $historyLookbackDays
    history_max_items = $historyMaxItems
    similar_topic_score_cap = $similarTopicScoreCap
    editorial_config_path = $editorialConfig.Path
    skill_path = $skillPath
    topic_categories = @($configuredTopicCategories | ForEach-Object { $_ })
    recent_decisions = @($recentDecisions | ForEach-Object { $_ })
    reports = @($reports | ForEach-Object { $_ })
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $paths.SourceManifestPath -Encoding UTF8

$reportPaths = @($reports | ForEach-Object { "- $($_.date): $($_.json_path)" }) -join [Environment]::NewLine
$readers = @($config.target_readers | ForEach-Object { "- $_" }) -join [Environment]::NewLine
$articleTypes = @($config.article_types.PSObject.Properties | ForEach-Object {
    "- $($_.Name): $($_.Value.label), $($_.Value.min_chars)-$($_.Value.max_chars) Chinese characters"
}) -join [Environment]::NewLine
$topicCategories = if ($configuredTopicCategories.Count -gt 0) {
    @($configuredTopicCategories | ForEach-Object { "- $($_.key): $($_.label)" }) -join [Environment]::NewLine
} else {
    "- general: General editorial topic"
}
$recentDecisionLines = if ($recentDecisions.Count -gt 0) {
    @($recentDecisions | ForEach-Object {
        $selectedTitles = if ($_.selected_titles.Count -gt 0) { ($_.selected_titles -join " | ") } else { "none" }
        "- $($_.date) [$($_.topic_category)] $($_.thesis)`n  reader_question: $($_.reader_question)`n  selected_items: $selectedTitles"
    }) -join [Environment]::NewLine
} else {
    "- None found in the configured history window."
}

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

Topic categories:
$topicCategories

Recent published editorial angles to avoid repeating:
$recentDecisionLines

Selection rules:
- Propose exactly 3 candidate angles and score each out of 100.
- Each candidate must include one topic_category from the configured keys.
- If possible, the 3 candidate angles should cover at least 2 different topic categories.
- Score reader relevance 15, novelty 10, recent topic distance 15, consequence 15, tension or counter-intuition 15, source strength 15, independent judgment 10, and title/visual potential 5.
- Recent topic distance means the angle should not repeat recent thesis, reader question, evidence set, or category unless there is a materially new event or an opposite conclusion.
- If a candidate is similar to any recent published angle, cap its score at $similarTopicScoreCap even if the evidence is strong. Mark the similar historical date and explain the penalty.
- Prefer categories not used in recent decisions when the evidence strength is comparable.
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
  "topic_category": "",
  "recent_topic_distance": "",
  "article_type": "$($config.default_article_type)",
  "thesis": "one clear Chinese sentence",
  "target_readers": [],
  "reader_question": "",
  "why_now": "",
  "candidate_angles": [
    {
      "angle": "",
      "topic_category": "",
      "score": 0,
      "recent_similarity": "none or similar to YYYY-MM-DD because ...",
      "score_adjustment": "none or capped at $similarTopicScoreCap because ...",
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
