param(
    [Parameter(Mandatory = $true)]
    [string]$DecisionPath
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "Editorial.Common.ps1")

$resolvedDecisionPath = (Resolve-Path -LiteralPath $DecisionPath).Path
$decision = Read-RequiredJson -Path $resolvedDecisionPath
if (-not [bool]$decision.publish) {
    throw "The editorial decision has publish=false. No article prompt will be generated. Reason: $($decision.reason)"
}
if ([string]::IsNullOrWhiteSpace([string]$decision.thesis)) {
    throw "The editorial decision is missing thesis."
}

$outputDir = Split-Path -Parent $resolvedDecisionPath
$manifestPath = Join-Path $outputDir "source-manifest.json"
$manifest = Read-RequiredJson -Path $manifestPath
$config = Read-RequiredJson -Path ([string]$manifest.editorial_config_path)
$articleTypeName = [string]$decision.article_type
$articleTypeProperty = $config.article_types.PSObject.Properties[$articleTypeName]
if ($null -eq $articleTypeProperty) {
    throw "Unknown article_type in editorial decision: $articleTypeName"
}
$articleType = $articleTypeProperty.Value
$skillPath = [string]$manifest.skill_path

$articlePromptPath = Join-Path $outputDir "editorial-article-prompt.md"
$titleCandidatesPath = Join-Path $outputDir "title-candidates.json"
$draftPath = Join-Path $outputDir "wechat-article-draft.md"
$imageDir = Join-Path $outputDir "imgs"
$selectedItems = @($decision.selected_items | ForEach-Object {
    "- $($_.title) | role=$($_.role) | date=$($_.report_date) | source=$($_.source_url)"
}) -join [Environment]::NewLine
$reportPaths = @($manifest.reports | ForEach-Object { "- $($_.date): $($_.json_path)" }) -join [Environment]::NewLine

$prompt = @"
# Draft a WeChat Editorial Article

Read the project skill completely:
$skillPath

Read the editorial decision:
$resolvedDecisionPath

Read all source reports:
$reportPaths

Core thesis:
$($decision.thesis)

Selected evidence:
$selectedItems

Write one Chinese WeChat editorial article. Do not summarize the daily reports and do not add unrelated news.

Article specification:
- Type: $articleTypeName ($($articleType.label))
- Length budget: $($articleType.min_chars)-$($articleType.max_chars) Chinese characters, excluding frontmatter and URLs.
- Use one thesis and at most three supporting conclusions.
- Make the strongest evidence carry most of the article; do not distribute length evenly.
- Open with the concrete change or tension. Do not invent a person, company scene, or anecdote.
- Use natural spoken-professional Chinese and restrained observational humor where appropriate.
- Preserve uncertainty. Distinguish claims, reports, and verified facts.
- Put ordinary inline Markdown source links next to important claims.
- Do not write a hand-made references section; the publishing step handles citations.
- Do not insert images yet. Visual planning happens after editorial review.
- Do not set author in frontmatter.

Generate exactly 10 honest title candidates across fact, judgment, question, counter-intuitive, and reader-specific angles. Write them as valid JSON to:
$titleCandidatesPath

Title JSON schema:
~~~json
{
  "recommended_title": "",
  "reason": "",
  "candidates": [
    {"title": "", "angle": "fact|judgment|question|counter_intuitive|reader_specific", "promise": ""}
  ]
}
~~~

Write the draft Markdown to:
$draftPath

Required frontmatter:
~~~yaml
---
title: "use recommended_title"
description: "80-120 Chinese characters; add information rather than repeat the title"
cover: "imgs/cover.png"
---
~~~

Before finishing, remove stock AI transitions, repeated conclusions, forced symmetry, and decorative jargon. Keep every source link intact. Reference local assets only under:
$imageDir
"@
$prompt | Set-Content -LiteralPath $articlePromptPath -Encoding UTF8

[PSCustomObject]@{
    DecisionPath = $resolvedDecisionPath
    ArticlePromptPath = $articlePromptPath
    TitleCandidatesPath = $titleCandidatesPath
    DraftPath = $draftPath
    NextStep = "Ask Codex to read editorial-article-prompt.md and write the title candidates and article draft."
} | ConvertTo-Json -Depth 5
